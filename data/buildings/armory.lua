-- Armory building: opens the Loadout panel (ui/panels/loadout.lua) to arrange each character's
-- 3x3 item grid. Positioned in the 1280x720 logical space, clear of the Quest Board hotspot.
return {
    name = "Armory",
    order = 2,
    x = 470,
    y = 430,
    w = 200,
    h = 120,
    panel = "loadout",
    unlockPrestige = 1,
}
