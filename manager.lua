
-- Pearl status persistence

local storage = minetest.get_mod_storage()

function pp.save_pearls()
    storage:set_string("pearls", minetest.serialize(pp.imprisoned_players))
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

local timer = 0
minetest.register_globalstep(function(dtime)
      timer = timer + dtime
      if timer < 60*5 then
         return
      end
      timer = 0
      pp.save_pearls()
end)

minetest.register_on_shutdown(pp.save_pearls)

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
    if create_pearl
       and inv
       and not inv:contains_item("main", stack)
    then
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

          -- Now we want to add the player to the tracker
          pp.imprisoned_players[victim] = {
             name = victim, location = location, isDirty = true
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
