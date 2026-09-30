-- Encounter blueprint. THE STILL POOL: Lust's stop for WANTING COSTS (reviewed 2026-09-29, pitched as "the
-- Still Water" and renamed, since that is already the name of Lust's elite, encounter_the_still_water).
-- A pool that shows each of the company something they want.
--
--   REACH IN    a sealed find, and the company opens the next fight on this floor Burning.
--   LOOK AWAY   nothing.
--
-- The dilemma is models/crossroads.lua's `STOPS.still_pool`, resolved by the Crossroads branch in
-- states/game.lua; "the next fight on this floor" is Descent.queueOpening.
--
-- `weight = 0`: never rolled. GUARANTEED once on each of Lust's floors (Descent.SINS' lust `stops`), and a
-- kept board keeps it spent once it is used.
return {
    name = "The Still Pool",
    kind = "still_pool",
    weight = 0,
    depth = 1,
}
