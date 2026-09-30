-- Encounter blueprint. THE CARCASS: Gluttony's stop for WASTEFULNESS and HUNGER (reviewed in three rounds,
-- 2026-09-29). A fresh kill, barely eaten, and one question: pick it over, eat, or walk on.
--
--   PICK IT OVER   a sealed find, and the beasts in the next fight on this floor open Starving 1.
--   EAT            the company heals a quarter of its health and opens the next fight on this floor Full 1.
--   LEAVE IT       nothing.
--
-- The dilemma is models/crossroads.lua's `STOPS.carcass`, resolved by the Crossroads branch in
-- states/game.lua; "the next fight on this floor" is Descent.queueOpening.
--
-- `weight = 0`: never rolled. It is GUARANTEED once on each of Gluttony's floors (Descent.SINS' gluttony
-- `stops`), and a kept board keeps it spent once it is used.
return {
    name = "The Carcass",
    kind = "carcass",
    weight = 0,
    depth = 1,
}
