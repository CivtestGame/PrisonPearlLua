
local function pearl_on_use(itemstack, user)
   -- Let's make sure this pearl is used
   local pname = user:get_player_name()
   local prisoner = pp.get_pearl_prisoner(itemstack)
   if prisoner then
      if pp.is_imprisoned(prisoner) then
         pp.free_pearl(prisoner)
         minetest.chat_send_player(pname, "Player " .. prisoner .. " has been freed.")
         pp.reset_pearl(itemstack)
         return itemstack
      else
         minetest.chat_send_player(pname, "Player is not imprisoned.")
      end
   end
end

local function pearl_on_drop(itemstack, dropper, pos)
   local prisoner = pp.get_pearl_prisoner(itemstack)
   if prisoner then
      if not pp.is_imprisoned(prisoner) then
         minetest.log("Faulty pearl detected with name: " .. prisoner .. ", deleting...")
         pp.reset_pearl(itemstack)
      else
         local pearl = pp.get_pearl_by_name(prisoner)
         local location = {type="ground", pos=pos}
         pp.update_pearl_location(pearl, location)
         minetest.log(
            dropper:get_player_name() .. " dropped the pearl of " .. prisoner
               .. " at (" .. vtos(pos) .. ")."
         )
      end
   end
   return minetest.item_drop(itemstack, dropper, pos)
end

minetest.register_craftitem("prisonpearl:pearl", {
	description = "Prison Pearl",
	inventory_image = "pearl.png",
	groups = {pearl = 1},
    stack_max = 1,
    on_secondary_use = pearl_on_use,
    on_drop = pearl_on_drop
})

-- TODO: change pearl acquisition method
minetest.register_craft({
	output = "prisonpearl:pearl",
	recipe = {
		{"", "default:cobble", ""},
		{"", "", ""},
		{"", "default:cobble", ""},
	}
})

local function register_pearl_pickup_tracker()
   -- there's no easy way to hook a player picking up an item, so we wrap the
   -- item entity's on_punch with a prisonpearl check.

   local def = core.registered_entities["__builtin:item"]
   minetest.log("item: " .. dump(def))
   -- local def = table.copy(olddef)
   local old_on_punch = def.on_punch
   local old_on_activate = def.on_activate
   local old_on_step = def.on_step

   def.on_step = function(self, dtime)
      if old_on_step then
         old_on_step(self, dtime)
      end

      if self.itemstring then
         local itemstack = ItemStack(self.itemstring)
         local item_is_a_pearl, prisoner = pp.is_itemstack_a_prisonpearl(itemstack)
         if item_is_a_pearl and prisoner then
            self.timer = self.timer or 0
            self.timer = self.timer + dtime
            if self.timer >= 1 then
               local pearl = pp.get_pearl_by_name(prisoner)
               if not pearl then
                  minetest.log("Found faulty pearl for " .. prisoner .. ", resetting...")
                  pp.reset_pearl(itemstack)
                  self:set_item(itemstack)
               elseif pearl.location.type ~= "ground" then
                  local pos = self.object:get_pos()
                  local location = { type="ground", pos=pos }
                  pp.update_pearl_location(pearl, location)
                  minetest.log(
                     "The pearl of " .. prisoner
                        .. " had location updated to ground at (" .. vtos(pos) .. ")."
                  )
               end
               self.timer = 0
            end
         end
      end
   end

   def.on_activate = function(self, staticdata, dtime_s)
      if old_on_activate then
         old_on_activate(self, staticdata, dtime_s)
      end

      -- itemstring should be set by now
      if self.itemstring then
         local itemstack = ItemStack(self.itemstring)
         local item_is_a_pearl, prisoner = pp.is_itemstack_a_prisonpearl(itemstack)
         if item_is_a_pearl and prisoner then
            local pearl = pp.get_pearl_by_name(prisoner)
            if not pearl then
               minetest.log("Found faulty pearl for " .. prisoner .. ", resetting...")
               pp.reset_pearl(itemstack)
               self:set_item(itemstack)
            else
               local pos = self.object:get_pos()
               local location = { type="ground", pos=pos }
               pp.update_pearl_location(pearl, location)
               minetest.log(
                  "The pearl of " .. prisoner .. " was dropped at ("
                     .. vtos(pos) .. ")."
               )
            end
         end
      end
   end

   def.on_punch = function(self, hitter)
      local itemstring = self.itemstring
      local inv = hitter:get_inventory()
      if inv
         and itemstring ~= ""
         and inv:room_for_item("main", itemstring)
      then
         local itemstack = ItemStack(itemstring)
         local item_is_a_pearl, prisoner = pp.is_itemstack_a_prisonpearl(itemstack)
         if item_is_a_pearl and prisoner then
            local pearl = pp.get_pearl_by_name(prisoner)
            if not pearl then
               minetest.log("Found faulty pearl for " .. prisoner .. ", resetting...")
               pp.reset_pearl(itemstack)
               self:set_item(itemstack)
            else
               local pname = hitter:get_player_name()
               local location = { type="player", name=pname }
               local pos = hitter:get_pos()
               pp.update_pearl_location(pearl, location)
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

register_pearl_pickup_tracker()
