
-- When a player leaves, drop any pearls they may hold.

minetest.register_on_leaveplayer(function(player, timed_out)
      local inv = player:get_inventory()
      if not inv then
         return
      end

      local lists = inv:get_lists()
      for listname, list in pairs(lists) do
         for _,stack in ipairs(list) do
            local stack_is_a_pearl, prisoner = pp.is_itemstack_a_prisonpearl(stack)
            local pearl_entry = pp.get_pearl_by_name(prisoner)
            if stack_is_a_pearl and pearl_entry then
               local pname = player:get_player_name()
               local pos = player:get_pos()
               minetest.log(
                  pname .. " disconnected holding pearl of " .. prisoner
                     .. " at (" .. vtos(pos) .. ")."
               )
               local on_drop = core.registered_items["prisonpearl:pearl"].on_drop
               -- for some reason dropping the pearl borks the pearl
               -- itemstack metadata, so we pass the prisoner name
               on_drop(stack, player, pos)
               pp.remove_pearl_item(player, prisoner)
            end
         end
      end
end)

-- Pearled players can't join the server.

minetest.register_on_prejoinplayer(function(pname, ip)
      local pearl = pp.get_pearl_by_name(pname)
      if pearl then
         local pos, message = pp.get_pos_by_type(pearl)
         return message
      end
end)

--------------------------------------------------------------------------------
--
-- Damage tracking via death/punch handlers
--
--------------------------------------------------------------------------------

-- Time to do damage calculation and see who to award a pearl to
local damageTable = {} -- Stored {playername: {attacker: damage}}
-- This variable stores the last time a player was attacked. Resets if no damage for 5 min
local lastHit = {} -- Stored {player_name: time}

--minetest.after(time, func, ...)

local function get_name_damage_player(name)
    local t = damageTable[name]
    if not t then
        return
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
    if not attacker then
        return
    end
    if pp.award_pearl(name, attacker) then
       minetest.chat_send_player(attacker, "You have imprisoned " .. name .. "!")
       damageTable[name] = nil
       lastHit[name] = nil
    end
end)


-- Handles calculating player damage to see who gets awarded an imprisonment

minetest.register_on_punchplayer(function(player, hitter, time_from_last_punch,
                                          tool_capabilities, dir, damage)
      local pname = player:get_player_name()
      local hname = hitter:get_player_name()

      -- Set damage table for player
      damageTable[pname] = damageTable[pname] or {}

      -- Insert hitter into damage table for player
      damageTable[pname][hname] = (damageTable[pname][hname] or 0) + damage

      local time = os.time(os.date("!*t"))
      lastHit[pname] = time
end)


local timer = 0
minetest.register_globalstep(function(dtime)
      timer = timer + dtime
      if timer < 10 then
         return
      end
      local time = os.time(os.date("!*t"))
      for pname,hit_time in pairs(lastHit) do
         if time > hit_time + 5 * 60 then
            lastHit[pname] = nil
         end
      end
end)

-- Handles movement into player inventories

minetest.register_on_player_inventory_action(
   function(player, action, inventory, inventory_info)
      if action ~= "put" then
         return
      end

      local stack = inventory_info.stack
      local stack_is_a_pearl, prisoner = pp.is_itemstack_a_prisonpearl(stack)
      local pearl_entry = pp.get_pearl_by_name(prisoner)
      if stack_is_a_pearl and pearl_entry then
         local pname = player:get_player_name()
         local pos = player:get_pos()
         minetest.log(
            pname .. " took pearl of " .. prisoner
               .. " at (" .. vtos(pos) .. ")."
         )
         pp.update_pearl_location(
            pearl_entry, { type = "player", name = pname }
         )
      end
   end
)
