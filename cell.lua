
--------------------------------------------------------------------------------
--
-- Util
--
--------------------------------------------------------------------------------

local function messager(player)
   local pname = (type(player) == "string" and player)
      or player:get_player_name()
   return function(msg)
      return minetest.chat_send_player(pname, msg)
   end
end

--------------------------------------------------------------------------------
--
-- Cell API
--
--------------------------------------------------------------------------------

function pp.player_has_cell(prisoner)
   local pearl_entry = pp.get_pearl_by_name(prisoner)
   if not pearl_entry then
      return false, "This player is no longer imprisoned."
   end

end

function pp.get_cell_core_assigned_player(pos)
   local meta = minetest.get_meta(pos)
   local assigned = meta:get_string("assigned_prisoner")
   if assigned ~= "" then
      return assigned
   end
end

function pp.set_cell_core_assigned_player(pos, prisoner)
   local meta = minetest.get_meta(pos)
   meta:set_string("assigned_prisoner", prisoner)
end

function pp.assign_cell(prisoner, pos)
   local assigned = pp.get_cell_core_assigned_player(pos)
   if assigned then
      return false, "This Cell Core is already assigned to '"..assigned.."'."
   end

   local pearl_entry = pp.get_pearl_by_name(prisoner)
   if not pearl_entry then
      return false, "This player is no longer imprisoned."
   end

   pp.set_cell_core_assigned_player(pos, prisoner)
   pp.update_pearl_location(pearl_entry, { type = "cell", pos = pos })
   pearl_entry.cell_new = true

   local node = { name = "prisonpearl:cell_core_occupied" }
   minetest.swap_node(pos, node)

   local meta = minetest.get_meta(pos)
   meta:set_string("infotext", prisoner .. "'s Prison Cell")

   return true, "'"..pearl_entry.name.."' was assigned to Cell Core at "
      .. minetest.pos_to_string(pos).."."
end

function pp.player_has_cell_core(pname)
   local pearl = pp.get_pearl_by_name(pname)
   if not pearl then
      return false
   end
   if pearl.location.type ~= "cell" then
      return false
   end
   return true, pearl
end

function pp.teleport_to_cell_core(player)
   local pname = player:get_player_name()
   local has_cell_core, pearl_entry = pp.player_has_cell_core(pname)
   if not has_cell_core then
      return
   end

   local pos = vector.new(pearl_entry.location.pos)
   pos.y = pos.y + 1
   player:set_pos(pos)
   pearl_entry.cell_new = false
end

--------------------------------------------------------------------------------
--
-- Node definition
--
--------------------------------------------------------------------------------

local has_citadella = minetest.get_modpath("citadella")

local function clamp(a, n, b)
   return math.max(math.min(b, n), a)
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
      local pos = minetest.string_to_pos(formname:split(";")[2])

      if formname:split(";")[1] ~= "prisonpearl:cell_core_manager" then
         return
      end

      local msg = messager(player)

      if has_citadella then
         local has_privilege, reinf, group
            = ct.has_locked_container_privilege(pos, player)
         if not has_privilege then
            msg("You cannot modify this Cell Core.")
            return
         end
      end

      local ppos = player:get_pos()
      if vector.distance(pos, ppos) > 5 then
         msg("You're too far away to modify this Cell Core.")
         return
      end

      if not fields then
         return
      end

      local meta = minetest.get_meta(pos)

      local new_width = (fields["cell_area_width"]
                            and tonumber(fields["cell_area_width"]))
         or tonumber(meta:get_string("cell_area_width")) or 3

      local new_height = (fields["cell_area_height"]
                             and tonumber(fields["cell_area_height"]))
         or tonumber(meta:get_string("cell_area_height")) or 3

      local new_muted = fields["cell_muted"]
         or meta:get_string("prisoner_muted") or "false"

      new_width = clamp(3, new_width, 128)
      meta:set_int("cell_width", new_width)

      new_height = clamp(3, new_height, 128)
      meta:set_int("cell_height", new_height)

      meta:set_string("prisoner_muted", new_muted)

      msg("Cell area: " .. tostring(new_width).."x"..tostring(new_height)
             .. ", mute: " .. new_muted)

      if not fields["quit"] and not fields["cell_muted"] then
         msg("Invalid Cell Core management form input.")
         return
      end
end)

local function make_cell_core_formspec(pos, cell_group)
   local F = minetest.formspec_escape
   local meta = minetest.get_meta(pos)
   local muted = meta:get_string("prisoner_muted")

   local cell_height = tostring(meta:get_int("cell_height"))
   local cell_width = tostring(meta:get_int("cell_width"))

   local group_string = (cell_group and "(Group: "..cell_group..")") or ""

   local assigned = meta:get_string("assigned_prisoner")

   local fs = {
      "size[5,4.25]",
      "label[0,0;", F(assigned), "'s Cell ", group_string, "]",

      "label[0,1;Cell Area (max 128 x 128):]",
      "field[1,2;1,0.6;cell_area_width;;", cell_width, "]",
      "label[1.75,1.75;x]",
      "field[2.5,2;1,0.6;cell_area_height;;", cell_height, "]",

      "checkbox[0,2.5;cell_muted;Mute Prisoner;", muted, "]",
      -- "button_exit[3,3.5;2,1;cell_free;Remove Cell]",
      "button[0,3.5;2,1;cell_area;Update Area]",
      "field_close_on_enter[cell_area;false]",
   }
   return table.concat(fs)
end

local function show_cell_core_formspec(player, pos)
   local msg = messager(player)
   local assigned = pp.get_cell_core_assigned_player(pos)
   if not assigned then
      msg("This Cell Core has not been assigned.")
      return
   end

   local cell_group = ""
   if has_citadella then
      local has_privilege, reinf, group
         = ct.has_locked_container_privilege(pos, player)
      if not has_privilege then
         msg("You cannot access this Cell Core.")
         return
      end
      cell_group = (group and group.name)
   end

   local pname = player:get_player_name()
   minetest.show_formspec(
      pname, "prisonpearl:cell_core_manager;"..minetest.pos_to_string(pos),
      make_cell_core_formspec(pos, cell_group)
   )
end

local function cell_core_on_construct(pos)
   local meta = minetest.get_meta(pos)
   meta:set_string("assigned_prisoner", "")
   meta:set_int("cell_height", 3)
   meta:set_int("cell_width", 3)
   meta:set_string("prisoner_muted", "false")
end

local function check_cell_clearance(pos)
   local pos_y_plus_1 = vector.new(pos.x, pos.y + 1, pos.z)
   local n1 = minetest.get_node_or_nil(pos_y_plus_1)
   if n1.name == "air" then
      local pos_y_plus_2 = vector.new(pos.x, pos.y + 2, pos.z)
      local n2 = minetest.get_node_or_nil(pos_y_plus_2)
      if n2.name == "air" then
         return true
      end
   end
   return false
end

local function cell_core_on_place(itemstack, placer, pointed_thing)
   local above = pointed_thing.above
   local has_clearance = check_cell_clearance(above)
   if not has_clearance then
      minetest.chat_send_player(
         placer:get_player_name(), "The two blocks above a Cell Core "
         .. "must be air."
      )
      return itemstack, false
   end

   return minetest.item_place(itemstack, placer, pointed_thing)
end

local function cell_core_on_punch(pos, node, puncher, pointed_thing)
   local msg = messager(puncher)
   local held = puncher:get_wielded_item()

   local is_pearl, prisoner = pp.is_itemstack_a_prisonpearl(held)
   if not is_pearl then
      return minetest.node_punch(pos, node, puncher, pointed_thing)
   elseif not prisoner then
      msg("This Prison Pearl has no prisoner.")
      return
   end

   local res, status = pp.assign_cell(prisoner, pos)
   if status then
      msg(status)
   end
   if res then
      puncher:set_wielded_item(ItemStack(nil))
   end
end

function pp.node_is_cell_core(pos)
   local node = minetest.get_node_or_nil(pos)
   if not node then
      return false
   end
   local node_name = node.name
   if node_name == "prisonpearl:cell_core"
      or node_name == "prisonpearl:cell_core_occupied"
   then
      return true
   else
      return false
   end
end

local function check_for_underneath_cell(pos)
   local pos_y_minus_1 = vector.new(pos.x, pos.y - 1, pos.z)
   if not pp.node_is_cell_core(pos_y_minus_1) then
      local pos_y_minus_2 = vector.new(pos.x, pos.y - 2, pos.z)
      if not pp.node_is_cell_core(pos_y_minus_2) then
         return false
      end
   end
   return true
end

local old_is_protected = minetest.is_protected
function minetest.is_protected(pos, pname, action)

   if action == minetest.PLACE_ACTION then
      local cell_is_underneath = check_for_underneath_cell(pos)
      if cell_is_underneath then
         minetest.chat_send_player(
            pname, "You cannot place blocks above a Cell Core!"
         )
         return true
      end
   end

   local has_cell_core, pearl_entry = pp.player_has_cell_core(pname)
   if not has_cell_core then
      return old_is_protected(pos, pname, action)
   end

   if pp.node_is_cell_core(pos) then
      minetest.chat_send_player(
         pname, "Imprisoned players cannot dig or interact with Cell Cores."
      )
      return true
   end

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


   if pos.x < cell_x_min or pos.x > cell_x_max or
      pos.z < cell_z_min or pos.z > cell_z_max or
      pos.y < cell_y_min or pos.y > cell_y_max
   then
      minetest.chat_send_player(
         pname, "You cannot modify blocks outside of your cell's limits."
      )
      return true
   end
end

local function cell_core_on_dig(pos, node, digger)
   local pname = digger:get_player_name()
   local has_cell_core, pearl_entry = pp.player_has_cell_core(pname)
   if has_cell_core and digger:is_player() then
      minetest.chat_send_player(
         digger:get_player_name(), "Imprisoned players cannot break Cell Cores."
      )
      return
   else
      return minetest.node_dig(pos, node, digger)
   end
end

local function cell_core_after_dig_node(pos, oldnode, oldmetadata, digger)
   local prisoner = oldmetadata.fields["assigned_prisoner"]
   if prisoner then
      local prisoner_msg = messager(prisoner)
      local digger_msg = messager(digger)

      pp.free_pearl(prisoner)
      prisoner_msg("You were freed from your Prison Cell.")
      digger_msg("You freed '" .. prisoner .. "' from their Prison Cell.")
   end
end

local function cell_core_on_rightclick(pos, node, clicker,
                                       itemstack, pointed_thing)
   show_cell_core_formspec(clicker, pos)
end

minetest.register_node("prisonpearl:cell_core",
   {
      	description = "Prison Cell Core",
	tiles = {
		"default_pedestal_top.png",
		"default_pedestal_top.png",
		"default_pedestal_side.png",
		"default_pedestal_side.png",
		"default_pedestal_side.png",
		"default_pedestal_side.png"
	},
	drawtype = "nodebox",
	paramtype = "light",
	node_box = {
		type = "fixed",
		fixed = {
			{-0.5, -0.5, -0.5, 0.5, -0.4375, 0.5}, -- NodeBox1
			{-0.4375, -0.4375, -0.4375, 0.4375, -0.375, 0.4375}, -- NodeBox2
			{-0.375, -0.375, 0.125, -0.125, -0.0625, 0.375}, -- NodeBox3
			{0.125, -0.375, 0.125, 0.375, -0.0625, 0.375}, -- NodeBox4
			{-0.375, -0.375, -0.375, -0.125, -0.0625, -0.125}, -- NodeBox5
			{0.125, -0.375, -0.375, 0.375, -0.0625, -0.125}, -- NodeBox6
			{-0.4375, -0.0625, -0.4375, 0.4375, 0, 0.4375}, -- NodeBox7
			{-0.375, 0, -0.375, 0.375, 0.0625, 0.375}, -- NodeBox8
                        {-0.25, -0.375, -0.25, 0.25, -0.0625, 0.25}, -- NodeBox20
		}
	},

        groups = { choppy = 1 },
        drop = "",
        sounds = default.node_sound_stone_defaults(),
        on_punch = cell_core_on_punch,
        on_construct = cell_core_on_construct,
        on_dig = cell_core_on_dig,
        on_rightclick = cell_core_on_rightclick,
        on_place = cell_core_on_place,
        after_dig_node = cell_core_after_dig_node
   }
)

minetest.register_craft({
	output = "prisonpearl:cell_core",
	recipe = {
		{"",               "default:obsidian", ""},
		{"default:basalt", "default:obsidian", "default:basalt"},
		{"default:basalt", "default:obsidian", "default:basalt" },
	}
})

minetest.register_node("prisonpearl:cell_core_occupied",
   {
      	description = "Prison Cell Core (Occupied)",
	tiles = {
		"default_pedestal_top_occupied.png",
		"default_pedestal_top.png",
		"default_pedestal_side_occupied.png",
		"default_pedestal_side_occupied.png",
		"default_pedestal_side_occupied.png",
		"default_pedestal_side_occupied.png"
	},
	drawtype = "nodebox",
	paramtype = "light",
	node_box = {
		type = "fixed",
		fixed = {
                   {-0.5, -0.5, -0.5, 0.5, -0.4375, 0.5}, -- NodeBox1
                   {-0.4375, -0.4375, -0.4375, 0.4375, -0.375, 0.4375}, -- NodeBox2
                   {-0.375, -0.375, 0.125, -0.125, -0.0625, 0.375}, -- NodeBox3
                   {0.125, -0.375, 0.125, 0.375, -0.0625, 0.375}, -- NodeBox4
                   {-0.375, -0.375, -0.375, -0.125, -0.0625, -0.125}, -- NodeBox5
                   {0.125, -0.375, -0.375, 0.375, -0.0625, -0.125}, -- NodeBox6
                   {-0.4375, -0.0625, -0.4375, 0.4375, 0, 0.4375}, -- NodeBox7
                   {-0.375, 0, -0.375, 0.375, 0.0625, 0.375}, -- NodeBox8
                   {-0.1875, 0.0625, -0.1875, 0.1875, 0.5, 0.1875}, -- NodeBox9
                   {-0.25, 0.0625, -0.25, 0.25, 0.4375, 0.25}, -- NodeBox19
                   {-0.25, -0.375, -0.25, 0.25, -0.0625, 0.25}, -- NodeBox20
		}
	},

        groups = { choppy = 1, not_in_creative_inventory = 1 },
        drop = "",
        sounds = default.node_sound_stone_defaults(),
        on_punch = cell_core_on_punch,
        on_construct = cell_core_on_construct,
        on_dig = cell_core_on_dig,
        on_rightclick = cell_core_on_rightclick,
        on_place = cell_core_on_place,
        after_dig_node = cell_core_after_dig_node
   }
)


--------------------------------------------------------------------------------
--
-- CivChat handler to enable the Cell Core prisoner mute
--
--------------------------------------------------------------------------------

local has_civchat = minetest.get_modpath("civchat")
if has_civchat then

   civchat.register_handler(function(from, to, msg)
         local has_cell_core, pearl_entry = pp.player_has_cell_core(from)
         if not has_cell_core then
            return true
         end

         local cell_pos = pearl_entry.location.pos

         local meta = minetest.get_meta(cell_pos)
         local from_has_cell_mute = meta:get_string("prisoner_muted")
         if from_has_cell_mute == "true" then
            minetest.chat_send_player(
               from, "You have been muted by your captor, so you cannot "
                  .. "use public chat."
            )
            return false
         end

         return true
   end)

end
