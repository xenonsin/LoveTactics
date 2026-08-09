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
-- THE GATE. The city's front door onto the descent, and the between-run screen the loop turns on.
--
-- This card used to be the Quest Board, and it keeps its slot rather than the descent taking one of
-- its own: the grid above is full -- eleven cards plus two narrow extras, all occupied -- so a
-- fourteenth building would break the layout this file's own header asks new content to keep to. It is
-- also the right corner on merit, being the first card in the city and the one a player walks to in
-- order to start something.
--
-- The board is not gone. ui/panels/descent.lua opens it as a nested panel ("Contracts"), because the
-- seven authored quest lines are still the only story content in the game until the descent carries
-- them, and deleting a working door before its replacement exists would cost the player seven lines
-- and buy nothing. The FILE keeps its name so the save's building order and any reference to it stay
-- put; only what stands there changed.
return {
    name = "The Gate",
    order = 1,
    x = 40,
    y = 150,
    w = 270,
    h = 140,
    panel = "descent",
    unlockPrestige = 1,
}
