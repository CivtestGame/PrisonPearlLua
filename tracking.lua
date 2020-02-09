-- Time to do damage calculation and see who to award a pearl to
local damageTable = {} -- Stored {playername: {attacker: damage}}
-- This variable stores the last time a player was attacked. Resets if no damage for 5 min
local lastHit = {} -- Stored {player_name: time}

--minetest.after(time, func, ...)

local function get_name_damage_player(name)
    local t = damageTable[name]
    if t == nil then
        return nil
    end
    -- Now we need to iterate and see which player did the most damage
    local mAttacker, mDamage = nil, 0
    for attacker, damage in pairs(t) do
        if damage > mDamage then -- Don't really care about if people do equal, just what ever was first
            -- We also want to to check if the player has a pearl, if they don't skip
            local location = {type="player", name=attacker}
            local inv = minetest.get_inventory(location)
            local stack = {name="prisonpearl:pearl", count=1, metadata=""}
            if inv and inv:contains_item("main", stack) then
                mDamage = damage
                mAttacker = attacker
                end
            end
        end
    return mAttacker
end

-- Handles player death and if they should be imprisoned
minetest.register_on_dieplayer(function(player)
    local name = player:get_player_name()
    -- Now lets see if there was a player that damaged them
    local attacker = get_name_damage_player(name)
    -- Check if attacker exists if not escape
    if attacker == nil then
        return
    end
    if pp.manager.award_pearl(name, attacker) then
       minetest.chat_send_player(attacker, "You have imprisoned " .. name .. "!")
       damageTable[name] = nil
       lastHit[name] = nil
    end
end)

-- Handles calculating player damage to see who gets awarded an imprisonment
minetest.register_on_punchplayer(function(player, hitter, time_from_last_punch, tool_capabilities, dir, damage)
    local playerName, hitterName = player:get_player_name(), hitter:get_player_name()
    if damageTable[playerName] == nil then
        damageTable[playerName] = {}
        end
    local tab = damageTable[playerName]
    if tab[hitterName] == nil then
        tab[hitterName] = 0
        end
    tab[hitterName] = tab[hitterName] + damage
end)

-- Handles
--minetest.item_drop(itemstack, dropper, pos)

minetest.register_on_player_inventory_action(function(player, action, inventory, inventory_info)
    --minetest.chat_send_player(player:get_player_name(), action)
    for index, name in pairs(inventory:get_location()) do
        --minetest.chat_send_player(player:get_player_name(), index.. ' ' .. tostring(name))
        end
end)

--------------------------------------------------------------------------------
--
-- Container PrisonPearl tracking hook wrappers
--
--------------------------------------------------------------------------------

function pp.wrap_on_metadata_inventory_put(def)
   local old_on_metadata_inventory_put = def.on_metadata_inventory_put
   def.on_metadata_inventory_put = function(pos, listname, index, stack, player)
      if pp.is_bound_prison_pearl(stack) then
         local pname = player:get_player_name()
         local prisoner = pp.get_pearl_prisoner(stack)
         local pearl = pp.manager.get_pearl_by_name(prisoner)
         if pearl then
            pp.manager.update_pearl_location(pearl, { type = "node", pos = pos })
            minetest.log(
               pname .. " placed " .. prisoner .. "'s pearl into " .. def.name
                  .. " at (" .. vtos(pos) .. ")."
            )
         end
      end
      if old_on_metadata_inventory_put then
         return old_on_metadata_inventory_put(pos, listname, index, stack, player)
      end
   end
   return def
end

function pp.wrap_on_metadata_inventory_take(def)
   local old_on_metadata_inventory_take = def.on_metadata_inventory_take
   def.on_metadata_inventory_take = function(pos, listname, index, stack, player)
      if pp.is_bound_prison_pearl(stack) then
         local pname = player:get_player_name()
         local prisoner = pp.get_pearl_prisoner(stack)
         local pearl = pp.manager.get_pearl_by_name(prisoner)
         if pearl then
            pp.manager.update_pearl_location(pearl, { type = "player", name = pname })
            minetest.log(
               pname .. " took " .. prisoner .. "'s pearl from " .. def.name
                  .. " at (" .. vtos(pos) .. ")."
            )
         end
      end
      if old_on_metadata_inventory_take then
         return old_on_metadata_inventory_take(pos, listname, index, stack, player)
      end
   end
   return def
end

function pp.override_definition(olddef)
   local def = table.copy(olddef)
   pp.wrap_on_metadata_inventory_put(def)
   pp.wrap_on_metadata_inventory_take(def)

   return def
end
