-- Building blueprint. `x,y,w,h` is the clickable hotspot rect in the 1280x720
-- logical space (see scale.lua). `panel` names a module under ui/panels/ that
-- opens when the building is clicked (nil -> generic placeholder panel).
-- `vendor` names a data/vendors/<id>.lua for shop buildings (panel = "party", store mode).
-- `state` names a module under states/ for the rare door that opens a whole SCREEN rather than a
-- pop-up (data/buildings/draft_yard.lua); a def sets one or the other, never both.
-- `unlockPrestige` is the minimum player prestige for the building to be active;
-- raise it on new buildings so the city visibly grows as prestige climbs.
--
-- The city is laid out on a 4/4/3 grid of 270x140 cards with 40px gutters: columns at
-- x = 40, 350, 660, 970 and rows at y = 150, 340, 530 (the last row is centered, at
-- x = 195, 505, 815). Keep new buildings on that grid so no two hotspots overlap. The bottom row
-- carries two narrow extras squeezed into its end gutters (Draft Yard, Dueling Grounds).
return {
    name = "Quest Board",
    order = 1,
    x = 40,
    y = 150,
    w = 270,
    h = 140,
    panel = "quest_board",
    unlockPrestige = 1,
}
