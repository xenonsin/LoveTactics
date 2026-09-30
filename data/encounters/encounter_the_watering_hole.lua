-- Encounter blueprint. THE WATERING HOLE: Gluttony's stop for SURVIVAL OF THE FITTEST (reviewed in three
-- rounds, 2026-09-29). Everything in the wood drinks here, in order of rank.
--
--   DRINK FIRST      every pool restored (Player.restore), and one member is injured.
--   WAIT YOUR TURN   half of every pool back (Player.refill).
--   WATCH THE ORDER  every elite still standing on this floor is revealed, for this trip.
--
-- The dilemma is models/crossroads.lua's `STOPS.watering_hole`, resolved by the Crossroads branch in
-- states/game.lua.
--
-- `weight = 0`: never rolled. It is GUARANTEED once on each of Gluttony's floors (Descent.SINS' gluttony
-- `stops`), and a kept board keeps it spent once it is used.
return {
    name = "The Watering Hole",
    kind = "watering_hole",
    weight = 0,
    depth = 1,
}
