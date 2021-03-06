
-- Nukes the pearls imprisoning prisoner from an inventory
function pp.remove_pearl_from_inv(inv, prisoner, revert)
   local lists = inv:get_lists()
   for listname, list in pairs(lists) do
      for i,stack in ipairs(list) do
         local is_a_pearl, item_prisoner = pp.is_itemstack_a_prisonpearl(stack)
         if is_a_pearl and item_prisoner == prisoner then
            local new_stack = ItemStack(nil)
            if revert then
               new_stack = pp.reset_pearl(inv:get_stack(listname, i))
            end
            inv:set_stack(listname, i, new_stack)
         end
      end
   end
end

function pp.is_itemstack_a_prisonpearl(itemstack)
   if itemstack and itemstack:get_name() == "prisonpearl:pearl" then
      local meta = itemstack:get_meta()
      local has_prisoner = meta:contains("prisoner")
      if has_prisoner then
         return true, meta:get_string("prisoner")
      end
      return true, nil
   end
   return false, nil
end

function pp.get_pearl_prisoner(itemstack)
   local is_pearl, prisoner = pp.is_itemstack_a_prisonpearl(itemstack)
   return prisoner
end

function pp.reset_pearl(itemstack)
   local meta = itemstack:get_meta()
   meta:set_string("prisoner", "")
   meta:set_string("description", "Prison Pearl")
   return itemstack
end

function pp.is_bound_prison_pearl(item)
   local meta = item:get_meta()
   return item:get_name() == "prisonpearl:pearl"
      and meta:get_string("prisoner") ~= ""
end

function pp.is_imprisoned(name)
    return pp.imprisoned_players[name] ~= nil
end

function pp.get_pearl_by_name(name)
    return pp.imprisoned_players[name]
end
