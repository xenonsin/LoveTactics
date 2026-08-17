-- Encounter blueprint. SOMEONE STILL STANDING: a body that came down here before you and has not fallen
-- yet, offering to walk the rest of it with you. The stop where a descent's company grows.
--
-- The descent walks in with ONE body and holds four (models/descent.lua), so three of any run's company
-- are found on the road rather than chosen at a gate. A floor with room in the company seats exactly one
-- of these, and stops seating it once the company is full -- see Descent.floorQuest's guaranteeKinds.
--
-- `kind = "recruit"`: a non-combat modal, resolved in states/game.lua, offering a slate of three
-- (models/descent_recruit.lua) of which one may join. `weight = 0`: authored-only, like the Rest, so it
-- never turns up on a rolled campaign board and never clusters -- the descent's guarantee is the only
-- thing that seats it.
return {
    name = "Someone Still Standing",
    kind = "recruit",
    weight = 0,
    minDay = 1,
}
