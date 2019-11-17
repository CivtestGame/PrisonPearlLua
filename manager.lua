local imprisoned_players = {} -- name : {pearl details}
local storage = minetest.get_mod_storage()
local function save_pearls()
    storage:set_string("pearls", minetest.serialize(imprisoned_players))
    minetest.debug("Saved Pearls")
    minetest.debug(minetest.serialize(imprisoned_players))
end

local function load_pearls()
    imprisoned_players = minetest.deserialize(storage:get_string("pearls"))
    if imprisoned_players == nil then
        imprisoned_players = {}
        end
    minetest.debug("Loaded Pearls")
end

--minetest.register_on_shutdown(function()
--    save_pearls()
--end)
load_pearls()
-- This function let's the mod know that we need to start tracking a pearl created from someone dying
function pp.manager.award_pearl(victim, attacker)
    -- Now we need to award a prison item to the attacker.
    local location = {type="player", name=attacker}
    local inv = minetest.get_inventory(location)
    for i, item in ipairs(inv:get_list("main")) do -- Update the item,
        if item:get_name() == "prisonpearl:pearl" then -- Now we need to check if it has metadata or not
            local meta = item:get_meta()
            if meta:get_string("prisoner") == "" then
               -- If no meta data then we know that we can use it
                meta:set_string("prisoner", victim)
                meta:set_string("description", victim .. " has been trapped")
                inv:set_stack("main", i, item)

                -- Now we want to add the player to the db tracking
                imprisoned_players[victim] = {name=victim, location=location, isDirty=true}
                -- Now we want to kick the player
                minetest.kick_player(victim, "You have been pearled!")
                save_pearls()
                return true
                end
            end
        end
    return false
end

function pp.manager.update_pearl_location(pearl, location)
    pearl.location = location
    pearl.isDirty = true
end

function pp.manager.is_imprisoned(name)
    return imprisoned_players[name] ~= nil
end

function pp.manager.get_pearl_by_name(name)
    return imprisoned_players[name]
end

function pp.manager.free_pearl(name)
    imprisoned_players[name] = nil
    -- minetest.unban_player_or_ip(name)
    save_pearls()
end

local function get_pos_by_type(pearl)
    if pearl.location.type == 'player' then
       local player = minetest.get_player_by_name(pearl.location.name)
       if player then
          return player:get_pos()
       else
          -- FIXME: Dirty defensive hack for cases where pearler logs out with
          -- pearl and the pearl object's location is stale...
          local pearled = pearl.name
          pp.manager.free_pearl(pearl.name)
          minetest.debug("Freed " .. pearled .. " (holder not found)")
          return nil
       end
    elseif pearl.location.type == 'node' then
        return pearl.location.pos
    elseif pearl.location.type == 'ground' then
        return pearl.location.pos
    end
end

-- Kick pearled players on join
minetest.register_on_joinplayer(function(player)
      local pname = player:get_player_name()
      if pp.manager.is_imprisoned(pname) then
         player:set_hp(0)
         local pearl = pp.manager.get_pearl_by_name(pname)
         local pos = get_pos_by_type(pearl)
         if pos then
            minetest.kick_player(pname, "You are pearled! Your pearl is at " .. vtos(pos))
         else
            minetest.chat_send_player(pname, "You were freed from your pearl!")
         end
      end
end)
