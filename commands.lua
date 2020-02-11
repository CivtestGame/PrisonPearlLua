
minetest.register_privilege("prisonpearl",{
   description = "PrisonPearl administration privilege."
})


minetest.register_chatcommand("ppfreeany", {
   params = "<player>",
   description = "Frees a player from imprisonment.",
   privs = { prisonpearl=true },
   func = function(name, player)
      local sender = minetest.get_player_by_name(name)
      if not sender then
         return false
      end
      local sender_name = sender:get_player_name()

      local pearl_entry = pp.get_pearl_by_name(player)
      if pearl_entry then
         local pos = pp.get_pos_by_type(pearl_entry)
         minetest.chat_send_player(
            sender_name,
            "Freed " .. player .. " from their imprisonment at ("
               .. vtos(pos) .. ") [" .. pearl_entry.location.type .. "]."
         )
         pp.free_pearl(pearl_entry.name)
         return true
      else
         minetest.chat_send_player(
            sender_name,
            "Player " .. player .. " is not currently imprisoned."
         )
         return false
      end
   end
})


minetest.register_chatcommand("ppimprisonany", {
   params = "<player>",
   description = "Imprisons a player in a PrisonPearl.",
   privs = { prisonpearl=true },
   func = function(name, player)
      local sender = minetest.get_player_by_name(name)
      if not sender then
         return false
      end
      local sender_name = sender:get_player_name()

      local pearl_entry = pp.get_pearl_by_name(player)

      if not pearl_entry then
         local was_awarded = pp.award_pearl(player, sender_name, true)
         if was_awarded then
            minetest.chat_send_player(
               sender_name,
               "Imprisoned " .. player .. ", check your inventory."
            )
            return true
         else
            minetest.chat_send_player(
               sender_name,
               "Pearling " .. player .. " failed, no space in inventory."
            )
            return false
         end
      else
         local pos = pp.get_pos_by_type(pearl_entry)
         minetest.chat_send_player(
            sender_name,
            "Player " .. player .. " is already imprisoned at ("
               .. vtos(pos) .. ") [" .. pearl_entry.location.type .. "]."
         )
         return false
      end
   end
})


minetest.register_chatcommand("pplocate", {
   params = "<player>",
   description = "Locates the PrisonPearl of an imprisoned player.",
   func = function(name, player)
      local sender = minetest.get_player_by_name(name)
      if not sender then
         return false
      end

      local sender_name = sender:get_player_name()
      local pearl_entry = pp.get_pearl_by_name(player)

      if not pearl_entry then
         minetest.chat_send_player(
            sender_name,
            "Player " .. player .. " is not imprisoned."
         )
      else
         local pos = pp.get_pos_by_type(pearl_entry)
         local msg = ""

         if pearl_entry.location.type == "player" then
            msg = "by " .. pearl_entry.location.name
         elseif pearl_entry.location.type == "node" then
            msg = "in a container"
         elseif pearl_entry.location.type == "ground" then
            msg = "on the ground"
         end

         minetest.chat_send_player(
            sender_name,
            "Player " .. player .. " is imprisoned " .. msg .. " at ("
               .. vtos(pos) .. ")."
         )
      end

      return true
   end
})
