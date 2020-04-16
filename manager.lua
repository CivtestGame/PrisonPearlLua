
-- Pearl status persistence

local storage = minetest.get_mod_storage()

function pp.save_pearls()
    -- Avoid serializing entity userdata in locations. A bit of a hack.
    local imprisoned_players_copy = {}
    for pname,entry in pairs(pp.imprisoned_players) do
       imprisoned_players_copy[pname] = entry
       imprisoned_players_copy[pname].entity = nil
    end

    storage:set_string("pearls", minetest.serialize(imprisoned_players_copy))
    minetest.log("[PrisonPearl] Saved pearls to disk.")
end

function pp.load_pearls()
    pp.imprisoned_players = minetest.deserialize(storage:get_string("pearls"))
    if pp.imprisoned_players == nil then
        pp.imprisoned_players = {}
    end
    minetest.log("[PrisonPearl] Loaded pearls from disk.")
end

pp.load_pearls()

local timer1 = 0
minetest.register_globalstep(function(dtime)
      timer1 = timer1 + dtime
      if timer1 < 60*5 then
         return
      end
      timer1 = 0
      pp.save_pearls()
end)

minetest.register_on_shutdown(pp.save_pearls)

-- Timer + globalstep to expire pearl entries if they've been held for too long

pp.PEARL_EXPIRY_TIME = 30 * 60
pp.PEARL_EXPIRY_GLOBALSTEP_INTERVAL = 60

local timer2 = 0
minetest.register_globalstep(function(dtime)
      timer2 = timer2 + dtime
      if timer2 < pp.PEARL_EXPIRY_GLOBALSTEP_INTERVAL then
         return
      end
      timer2 = 0

      local time = os.time(os.date("!*t"))
      for pname,entry in pairs(pp.imprisoned_players) do
         local location = entry.location

         entry.creation_time = entry.creation_time or time

         -- Check for expiry of imprisonments that are not tied to a cell.
         if location.type ~= "cell"
            and entry.creation_time + pp.PEARL_EXPIRY_TIME < time
         then
            if location.type == "ground" then
               -- Remove expired pearls that have been dropped (item entities).
               local item_entity = location.entity
               if item_entity then
                  item_entity.itemstring = ""
                  item_entity.object:remove()
                  minetest.log(
                     "Dropped pearl of " .. pname .. " at "
                        .. minetest.pos_to_string(location.pos) .. " expired. "
                        .. "Item entity was removed."
                  )
                  pp.free_pearl(pname)
               else
                  minetest.log(
                     "Faulty pearl item entity for player " .. pname
                        .. " at " .. minetest.pos_to_string(location.pos)
                        .. ". This should fix itself."
                  )
               end
            else
               -- Remove expired pearls that are in a player or node inventory.
               local inv = minetest.get_inventory(location)
               if location.type == "player" then
                  minetest.chat_send_player(
                     location.name, "Your held Prison Pearl of '"
                        .. pname .. "' expired, and the player was freed!"
                  )
               end

               local holder_pos = location.pos
                  or minetest.get_player_by_name(location.name):get_pos()

               local holder_desc = location.name and " " .. location.name

               minetest.log(
                  "Pearl of " .. pname .. " expired in inventory of "
                     .. location.type .. (holder_desc or "") .. " at "
                     .. minetest.pos_to_string(holder_pos) .. "."
               )

               pp.remove_pearl_from_inv(inv, pname)
               pp.free_pearl(pname)
            end
         end
      end
end)

-- This function lets the mod know that we need to start tracking a pearl
-- created from someone dying
function pp.award_pearl(victim, attacker, create_pearl)
    -- First, ignore attempts to re-imprison an already imprisoned player
    local pearl_entry = pp.get_pearl_by_name(victim)
    if pearl_entry then
       minetest.chat_send_player(
          attacker, victim .. " is already imprisoned at "
             .. minetest.pos_to_string(pearl_entry.location.pos) .. "."
       )
       return false
    end

    -- Find (or create) a suitable empty PrisonPearl
    local location = {type="player", name=attacker}
    local inv = minetest.get_inventory(location)
    local stack = {name="prisonpearl:pearl", count=1, metadata=""}

    if create_pearl and inv then
       if inv:room_for_item("main", stack) then
          inv:add_item("main", stack)
       else
          return false
       end
    end

    for i, item in ipairs(inv:get_list("main")) do
       local is_pearl, prisoner = pp.is_itemstack_a_prisonpearl(item)
       if is_pearl and not prisoner then
          -- If no prisoner metadata then we know that we can use this pearl
          local meta = item:get_meta()
          meta:set_string("prisoner", victim)
          meta:set_string("description", victim .. "'s PrisonPearl")
          inv:set_stack("main", i, item)
          local time = os.time(os.date("!*t"))

          -- Now we want to add the player to the tracker
          pp.imprisoned_players[victim] = {
             name = victim, location = location, isDirty = true,
             creation_time = time
          }
          -- Now we want to kick the player
          minetest.kick_player(victim, "You have been pearled!")
          pp.save_pearls()
          return true
       end
    end

    return false
end

function pp.update_pearl_location(pearl, location)
    pearl.location = location
    pearl.isDirty = true
end

function pp.free_pearl(name)
    pp.imprisoned_players[name] = nil
    -- minetest.unban_player_or_ip(name)
    pp.save_pearls()
end

function pp.get_pos_by_type(pearl)
    if pearl.location.type == 'player' then
       local player = minetest.get_player_by_name(pearl.location.name)
       if player then
          local pos = player:get_pos()
          return pos, "Your pearl is held by "
             .. player:get_player_name() .. " at " .. vtos(vector.floor(pos)) .. "."
       else
          -- FIXME: Dirty defensive hack for cases where pearler logs out with
          -- pearl and the pearl object's location is stale...
          local pearled = pearl.name
          pp.free_pearl(pearl.name)
          minetest.debug("Freed " .. pearled .. " (holder not found)")
          return nil, "You have been freed! Please log back in."
       end
    elseif pearl.location.type == 'node' then
       local pos = pearl.location.pos
       return pos, "Your pearl is held in a container at " .. vtos(pos) .. "."
    elseif pearl.location.type == 'cell' then
       local pos = pearl.location.pos
       return pos, "Your pearl is assigned to the Cell Core at "
          .. vtos(pos) .. "."
    elseif pearl.location.type == 'ground' then
       local pos = pearl.location.pos
       return pos, "Your pearl is on the ground at " .. vtos(pos) .. "."
    end
end
