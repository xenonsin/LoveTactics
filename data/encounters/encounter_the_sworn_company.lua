-- THE SWORN COMPANY: an oath-bound four, and the band's mid-depth shape.
--
-- A sentinel carrying what the others take, a monk that does not need a weapon, and a forsworn captain
-- who has been down here longer than either. Rung 5.
--
-- IT FLOATS, WHICH IS THE WHOLE OF WHY IT IS HUMAN. Under the circle-lock rule every body that is not
-- human belongs to exactly one circle and appears nowhere else -- so the human band is the only thing
-- that can stand on any floor, and it is therefore what keeps a floor from being empty at a depth its
-- circle has not been authored out to yet. Nothing here declares a `condition`: that absence is the
-- feature.
--
-- ITS DEPTH IS ITS `depth` AND THAT IS A STOPGAP. What ought to place this is a depth band read off
-- the floor count, the way an item's `unlockLevel` is -- the gate is still the campaign calendar's day
-- and the descent borrows one. Until that lands, the rung of the bodies below is the real statement
-- about where this belongs: a company is made of what the floor could plausibly have produced
-- (Class.gateLevel, which models/warband.lua's generator already reads).
return {
    name = "The Sworn Company",
    kind = "combat",
    weight = 3,
    depth = 3,
    composition = { "character_sentinel", "character_monk", "character_forsworn_captain", "character_forsworn_knight" },
}
