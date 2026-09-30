-- Encounter blueprint. THE FERRY: Lust's stop for WHERE YOU STAND (reviewed 2026-09-29). A flat boat tied at
-- a channel, with a pole and no ferryman.
--
--   RIDE IT    the company is carried to ground it has not walked, somewhere far off on this floor, and does
--              not choose where (game:ferry -- the Translation's move, pointed at unseen ground instead of seen).
--   LEAVE IT   nothing.
--
-- The dilemma is models/crossroads.lua's `STOPS.ferry`.
--
-- `weight = 0`: never rolled. GUARANTEED once on each of Lust's floors (Descent.SINS' lust `stops`), and a
-- kept board keeps it spent once it is used.
return {
    name = "The Ferry",
    kind = "ferry",
    weight = 0,
    depth = 1,
}
