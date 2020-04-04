
--------------------------------------------------------------------------------
--
-- Util
--
--------------------------------------------------------------------------------

local function messager(puncher)
   local pname = (type(puncher) == "string" and puncher)
      or puncher:get_player_name()
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
            msg("You cannot access this Cell Core.")
            return
         end
      end

      if not fields then
         return
      end

      minetest.log("fields: " .. dump(fields))

      local new_width = tonumber(fields["cell_area_width"])
      local new_height = tonumber(fields["cell_area_height"])
      local new_muted = (fields["cell_muted"] and "YES") or "NO"
      if new_width and new_width then
         local meta = minetest.get_meta(pos)
         meta:set_int("cell_height", new_height)
         meta:set_int("cell_width", new_width)
         meta:set_string("prisoner_muted", new_muted)
         msg("Cell area set to "..new_height.." x "..new_width..". "
                .."Prisoner mute: "..tostring(new_muted)..".")
      elseif not fields["quit"] then
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
      "field[1,2;1,0.6;cell_area_height;;", cell_height, "]",
      "label[1.75,1.75;x]",
      "field[2.5,2;1,0.6;cell_area_width;;", cell_width, "]",

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

local function cell_core_on_punch(pos, node, puncher, pointed_thing)
   local msg = messager(puncher)
   local held = puncher:get_wielded_item()

   local is_pearl, prisoner = pp.is_itemstack_a_prisonpearl(held)
   if not is_pearl then
      return
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

local old_is_protected = minetest.is_protected
function minetest.is_protected(pos, pname, action)
   local has_cell_core, pearl_entry = pp.player_has_cell_core(pname)
   if not has_cell_core then
      return old_is_protected(pos, pname, action)
   end

   local node = minetest.get_node(pos)
   if node.name == "prisonpearl:cell_core" then
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

local function cell_core_on_rightclick(pos, node, clicker,
                                       itemstack, pointed_thing)
   show_cell_core_formspec(clicker, pos)
end

minetest.register_node("prisonpearl:cell_core",
   {
      	description = "Prison Cell Core",
        tiles = { "^[colorize:#f00f3d:255" },
        groups = { choppy = 1 },
        drop = "",
        sounds = default.node_sound_stone_defaults(),
        on_punch = cell_core_on_punch,
        on_construct = cell_core_on_construct,
        on_dig = cell_core_on_dig,
        on_rightclick = cell_core_on_rightclick,
   }
)
