-- Building blueprint. `x,y,w,h` is the clickable hotspot rect in the 1280x720
-- logical space (see scale.lua). `panel` names a module under ui/panels/ that
-- opens when the building is clicked (nil -> generic placeholder panel).
-- `unlockPrestige` is the minimum player prestige for the building to be active;
-- raise it on new buildings so the city visibly grows as prestige climbs.
return {
    name = "Quest Board",
    order = 1,
    x = 140,
    y = 430,
    w = 200,
    h = 120,
    panel = "quest_board",
    unlockPrestige = 1,
}
