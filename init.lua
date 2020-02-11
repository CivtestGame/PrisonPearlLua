
local modpath = minetest.get_modpath(minetest.get_current_modname())

pp = {}

-- Table tracking which players are imprisoned

pp.imprisoned_players = {}

dofile(modpath .. "/api.lua")
dofile(modpath .. "/item.lua")
dofile(modpath .. "/manager.lua")
dofile(modpath .. "/tracking.lua")
dofile(modpath .. "/handlers.lua")
dofile(modpath .. "/commands.lua")

minetest.debug("PrisonPearl initialised.")

return pp
