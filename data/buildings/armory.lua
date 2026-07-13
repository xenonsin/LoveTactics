-- Armory building: opens the Party screen (ui/panels/party.lua) in stash mode to arrange each
-- character's 3x3 item grid and move gear to/from the stash. Not a vendor -- it rearranges what you
-- already own (no `vendor` field, so the Party panel shows the Stash rather than a Store).
return {
    name = "Armory",
    order = 2,
    x = 350,
    y = 150,
    w = 270,
    h = 140,
    panel = "party",
    unlockPrestige = 1,
}
