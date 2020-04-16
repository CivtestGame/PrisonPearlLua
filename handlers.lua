
-- When a player leaves, drop any pearls they may hold.

minetest.register_on_leaveplayer(function(player, timed_out)
      local inv = player:get_inventory()
      if not inv then
         return
      end

      local lists = inv:get_lists()
      for listname, list in pairs(lists) do
         for _,stack in ipairs(list) do
            local is_a_pearl, prisoner = pp.is_itemstack_a_prisonpearl(stack)
            local pearl_entry = pp.get_pearl_by_name(prisoner)
            if is_a_pearl and pearl_entry then
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
               pp.remove_pearl_from_inv(inv, prisoner)
            end
         end
      end
end)

-- Pearled players can't join the server.

minetest.register_on_prejoinplayer(function(pname, ip)
      local pearl = pp.get_pearl_by_name(pname)
      if not pearl then
         return
      end

      if pearl.location.type == "cell" then
         return
      end

      local pos, message = pp.get_pos_by_type(pearl)
      return message
end)

-- Celled players respawn in their cell

minetest.register_on_joinplayer(function(player)
      local pname = player:get_player_name()
      local has_cell_core, pearl_entry = pp.player_has_cell_core(pname)
      if not has_cell_core then
         return
      end

      if not pearl_entry.cell_new then
         return
      end

      minetest.after(
         3,
         function()
            minetest.chat_send_player(
               pname, "While away, were assigned to a Prison Cell!"
            )
         end
      )
      pp.teleport_to_cell_core(player)
end)

minetest.register_on_respawnplayer(function(player)
      local pname = player:get_player_name()
      local has_cell_core, pearl_entry = pp.player_has_cell_core(pname)
      if not has_cell_core then
         return
      end

      pp.teleport_to_cell_core(player)

      minetest.chat_send_player(
         pname, "You respawned in your Prison Cell."
      )
end)


local timer = 0
minetest.register_globalstep(function(dtime)
      timer = timer + dtime
      if timer < 1 then
         return
      end
      timer = 0

      for _,player in ipairs(minetest.get_connected_players()) do
         local pname = player:get_player_name()
         local has_cell, pearl_entry = pp.player_has_cell_core(pname)
         if has_cell then
            local cell_pos = pearl_entry.location.pos
            local meta = minetest.get_meta(cell_pos)
            local cell_h = meta:get_int("cell_height")
            local cell_w = meta:get_int("cell_width")

            local cell_x_min = cell_pos.x - cell_w
            local cell_x_max = cell_pos.x + cell_w
            local cell_z_min = cell_pos.z - cell_w
            local cell_z_max = cell_pos.z + cell_w

            local cell_y_min = cell_pos.y - cell_h
            local cell_y_max = cell_pos.y + cell_h

            local ppos = player:get_pos()

            local new_x
            if ppos.x < cell_x_min then
               new_x = cell_x_min
            elseif ppos.x > cell_x_max then
               new_x = cell_x_max
            end

            local new_z
            if ppos.z < cell_z_min then
               new_z = cell_z_min
            elseif ppos.z > cell_z_max then
               new_z = cell_z_max
            end

            local new_y
            if ppos.y < cell_y_min then
               minetest.chat_send_player(
                  pname, "You fell out of your cell and were teleported back."
               )
               pp.teleport_to_cell_core(player)
               goto continue
            elseif ppos.z > cell_z_max then
               new_y = cell_y_max
            end

            if new_x or new_z or new_y then
               ppos.x = new_x or ppos.x
               ppos.z = new_z or ppos.z
               ppos.y = new_y or ppos.y
               minetest.chat_send_player(pname, "You cannot leave your cell!")
               player:set_pos(ppos)
            end

            ::continue::
         end
      end
end)

--------------------------------------------------------------------------------
--
-- Damage tracking via death/punch handlers
--
--------------------------------------------------------------------------------

-- Time to do damage calculation and see who to award a pearl to
pp.damageTable = {} -- Stored {playername: {attacker: damage}}
-- This variable stores the last time a player was attacked. Resets if no damage for 5 min
pp.lastHit = {} -- Stored {player_name: time}

--minetest.after(time, func, ...)

function pp.get_main_attacker(name)
    local t = pp.damageTable[name]
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
    local attacker = pp.get_main_attacker(name)
    if not attacker then
        return
    end
    if pp.award_pearl(name, attacker) then
       minetest.chat_send_player(attacker, "You have imprisoned " .. name .. "!")
       pp.damageTable[name] = nil
       pp.lastHit[name] = nil
    end
end)


-- Handles calculating player damage to see who gets awarded an imprisonment

minetest.register_on_punchplayer(function(player, hitter, time_from_last_punch,
                                          tool_capabilities, dir, damage)
      local pname = player:get_player_name()
      local hname = hitter:get_player_name()

      -- Set damage table for player
      pp.damageTable[pname] = pp.damageTable[pname] or {}

      -- Insert hitter into damage table for player
      pp.damageTable[pname][hname] = (pp.damageTable[pname][hname] or 0) + damage

      local time = os.time(os.date("!*t"))
      pp.lastHit[pname] = time
end)


local timer = 0
minetest.register_globalstep(function(dtime)
      timer = timer + dtime
      if timer < 10 then
         return
      end
      local time = os.time(os.date("!*t"))
      for pname,hit_time in pairs(pp.lastHit) do
         if time > hit_time + 5 * 60 then
            pp.lastHit[pname] = nil
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
