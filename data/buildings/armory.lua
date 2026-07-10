-- Armory building: opens the Loadout panel (ui/panels/loadout.lua) to arrange each character's
-- 3x3 item grid. Not a vendor -- it rearranges what you already own.
return {
    name = "Armory",
    order = 2,
    x = 350,
    y = 150,
    w = 270,
    h = 140,
    panel = "loadout",
    unlockPrestige = 1,
}
