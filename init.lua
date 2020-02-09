-- Load config parameters
local modpath = minetest.get_modpath(minetest.get_current_modname())

minetest.debug("PrisonPearl initialised.")

minetest.register_craft({
	output = "prisonpearl:pearl",
	recipe = {
		{"", "default:cobble", ""},
		{"", "", ""},
		{"", "default:cobble", ""},
	}
})

local function pearl_on_use(itemstack, user)
    -- Let's make sure this pearl is used
    local meta = itemstack:get_meta()
    if meta:contains("prisoner") then
        local name = meta:get_string("prisoner")
        if pp.manager.is_imprisoned(name) then
            pp.manager.free_pearl(name)
            minetest.chat_send_player(user:get_player_name(), "Player " .. name .. " has been freed.")
            local meta = itemstack:get_meta()
            meta:set_string("prisoner", "")
            meta:set_string("description", "Prison Pearl")
            return itemstack
        else
            minetest.chat_send_player(user:get_player_name(), "Player is not imprisoned.")
            end
        end
end

minetest.register_craftitem("prisonpearl:pearl", {
	description = "Prison Pearl",
	inventory_image = "pearl.png",
	groups = {pearl = 1},
    stack_max = 1,
    on_secondary_use = pearl_on_use,
    on_drop = function(itemstack, dropper, pos)
        local meta = itemstack:get_meta()
        if meta:contains("prisoner") then
            local name = meta:get_string("prisoner")
            pearl = pp.manager.get_pearl_by_name(name)
            if not pearl then
                minetest.log("Faulty pearl detected with name: " .. name .. ", deleting...")
                local meta = itemstack:get_meta()
                meta:set_string("prisoner", "")
                meta:set_string("description", "Prison Pearl")
            else
                local location = {type="ground", pos=pos}
                pp.manager.update_pearl_location(pearl, location)
                minetest.log(
                   dropper:get_player_name() .. " dropped the pearl of " .. name
                      .. " at (" .. vtos(pos) .. ")."
                )
            end
        end
        minetest.item_drop(itemstack, dropper, pos)
        return itemstack
    end,

})

local function register_pearl_pickup()
   -- there's no easy way to hook a player picking up an item, so we wrap the
   -- item entity's on_punch with a prisonpearl check.

   local def = core.registered_entities["__builtin:item"]
   -- local def = table.copy(olddef)
   local old_on_punch = def.on_punch

   def.on_punch = function(self, hitter)
      local itemstring = self.itemstring
      local inv = hitter:get_inventory()
      if inv
         and itemstring ~= ""
         and inv:room_for_item("main", itemstring)
      then
         local itemstack = ItemStack(itemstring)
         if itemstack:get_name() == "prisonpearl:pearl" then
            local meta = itemstack:get_meta()
            local prisoner = meta:get_string("prisoner")
            local pearl = pp.manager.get_pearl_by_name(prisoner)
            if not pearl then
               minetest.log("Faulty pearl detected with name: " .. prisoner .. ", deleting...")
               meta:set_string("prisoner", "")
               meta:set_string("description", "Prison Pearl")
            else
               local pname = hitter:get_player_name()
               local location = { type="player", name=pname }
               local pos = hitter:get_pos()
               pp.manager.update_pearl_location(pearl, location)
               minetest.log(
                  pname .. " picked up the pearl of " .. prisoner
                     .. " at (" .. vtos(pos) .. ")."
               )
            end
         end
      end
      if old_on_punch then
         old_on_punch(self, hitter)
      end
   end

   -- core.register_entity(":__builtin:item", def)
end

register_pearl_pickup()

-- Lets handle all situations when a prisonshard is moved
pp = {}
pp.manager = {}
pp.tracker = {}
dofile(modpath .. "/manager.lua")
dofile(modpath .. "/tracking.lua")
return pp
