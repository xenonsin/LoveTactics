-- Encounter blueprint. THE MOORING POST: Lust's stop for ROOT and COILED -- whether you leave (reviewed
-- 2026-09-29). A post in the fen, its ropes worn smooth.
--
--   TIE IN FOR THE NIGHT   every pool restored, and the company opens the next fight on this floor Rooted:
--                          it cannot move, and it cannot be moved -- which on this circle's ground, among
--                          the harpies and the channels, is half of a blessing.
--   WALK ON                nothing.
--
-- The dilemma is models/crossroads.lua's `STOPS.mooring_post`.
--
-- `weight = 0`: never rolled. GUARANTEED once on each of Lust's floors (Descent.SINS' lust `stops`), and a
-- kept board keeps it spent once it is used.
return {
    name = "The Mooring Post",
    kind = "mooring_post",
    weight = 0,
    depth = 1,
}
