--------------------------------------------------------------------------------
--
-- Container PrisonPearl tracking hook wrappers
--
--------------------------------------------------------------------------------

function pp.wrap_on_metadata_inventory_put(def)
   local old_on_metadata_inventory_put = def.on_metadata_inventory_put
   def.on_metadata_inventory_put = function(pos, listname, index, stack, player)
      local stack_is_a_pearl, prisoner = pp.is_itemstack_a_prisonpearl(stack)
      local pearl_entry = pp.get_pearl_by_name(prisoner)
      if stack_is_a_pearl and pearl_entry then
         local pname = player:get_player_name()
         pp.update_pearl_location(pearl_entry, { type = "node", pos = pos })
         minetest.log(
            pname .. " placed " .. prisoner .. "'s pearl into " .. def.name
               .. " at (" .. vtos(pos) .. ")."
         )
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
      local stack_is_a_pearl, prisoner = pp.is_itemstack_a_prisonpearl(stack)
      local pearl_entry = pp.get_pearl_by_name(prisoner)
      if stack_is_a_pearl and pearl_entry then
         local pname = player:get_player_name()
         pp.update_pearl_location(pearl_entry, { type = "player", name = pname })
         minetest.log(
            pname .. " took " .. prisoner .. "'s pearl from " .. def.name
               .. " at (" .. vtos(pos) .. ")."
         )
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
