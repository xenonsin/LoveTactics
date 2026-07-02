-- Building blueprint. `x,y,w,h` is the clickable hotspot rect in the 800x600
-- window space (see conf.lua). `panel` names a module under ui/panels/ that
-- opens when the building is clicked (nil -> generic placeholder panel).
-- `unlockPrestige` is the minimum player prestige for the building to be active;
-- raise it on new buildings so the city visibly grows as prestige climbs.
return {
    name = "Quest Board",
    order = 1,
    x = 90,
    y = 380,
    w = 150,
    h = 90,
    panel = "quest_board",
    unlockPrestige = 1,
}
