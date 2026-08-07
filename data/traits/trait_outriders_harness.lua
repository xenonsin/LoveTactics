-- Outrider's Harness: the standing rule of the Skirmisher's armour. A blow thrown by somebody who has
-- covered two tiles or more this turn cannot be answered.
--
-- A flag (Trait.flag) read in Trait.mayCounter, the one gate every retaliation in the game passes
-- through -- so it silences parries, ripostes, thorns and reflecting wards together, and the hover
-- preview promises the same silence the swing delivers.
--
-- This is rule R1 doing its work. The armour was drafted with "+1 movement", which the author cut on the
-- grounds that no armour should ever grant a square: the movement tiers in the armor spread are a cost
-- table, and a piece that hands one back cancels them. What replaced it is better anyway -- a movement
-- bonus is a number, and "they do not get to hit you back" is a thing you can watch happen.
--
-- Measured as distance from where the turn opened (Combat.tilesMovedThisTurn), not steps taken: a rider
-- who circles back to the same tile has covered no ground, whatever the pathfinder counted.
return {
    name = "Outrider's Harness",
    description = "A blow you throw after covering two tiles or more cannot be answered.",
    unanswerableAfterMove = true,
}
