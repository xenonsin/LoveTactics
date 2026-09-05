-- Encounter blueprint. THE DARK: ground the lamp will not reach into, and the first of the three
-- hazards that make a descent floor a place that lies to you rather than a route with fights on it.
--
-- WHAT WIZARDRY'S DARKNESS SQUARES ACTUALLY DO, translated. There, they kill your light spell and you
-- walk blind, mapping by counting steps and hoping. Here the map is drawn for you, so the thing that
-- can be taken away is the RADIUS: vision drops to a single tile for a stretch of walking, so the fog
-- closes to arm's length and everything ahead has to be walked into rather than read.
--
-- It is a real cost rather than a nuisance because of what else is on the board. The tier pips on a
-- fight, the guarded reward one tile past its guard, the way up -- every one of those is something the
-- player reads at a distance to decide with, and the dark is the stop that takes reading away and
-- leaves them deciding by walking.
--
-- `kind = "dark"`, resolved in states/game.lua. `weight = 0`, so it never turns up on a rolled campaign
-- board -- the descent's own pool is the only thing that gives it a weight (models/descent.lua's
-- Descent.floorPool), which is what scopes all three hazards to the floors they were written for.
return {
    name = "The Dark",
    kind = "dark",
    weight = 0,
    minDay = 1,
}
