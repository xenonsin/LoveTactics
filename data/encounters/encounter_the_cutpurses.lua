-- THE CUTPURSES: the first company that is a COMBO rather than a line.
--
-- A thief opens your purse, a bulwark makes sure you cannot walk away from him, and an elementalist is
-- paid for the two of them holding you still. Every body is rung 3, so this is the shallowest depth at
-- which the band can field a discipline at all.
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
    name = "The Cutpurses",
    kind = "combat",
    weight = 4,
    depth = 2,
    composition = { "character_thief", "character_bulwark", "character_elementalist", "character_bandit" },
}
