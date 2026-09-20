-- THE SHORTENED ARM: everything the bearer reaches for is one tile further away than it was.
--
-- `rules.abilityRange = -1`, AND THE ENGINE ALREADY FLOORS IT AT ONE. Combat.abilityRange ends on
-- `math.max(1, range)` -- written for Blind, whose own note says a blinded unit is "groping in the dark,
-- not disarmed" -- so a knight under this still swings at the body in front of it and loses almost
-- nothing. An archer loses a third of its standoff and a mage has to walk into the room.
--
-- SO ITS WEIGHT IS SET BY WHO IS CARRYING IT, which is The Blood Price's trick six rungs cheaper and the
-- reason this sits at depth 3 rather than at depth 1. It is the first hex that makes the player think
-- about WHICH body should be holding the hexed piece -- and, once Rebind exists, the first one worth
-- moving.
return {
    name = "The Shortened Arm",
    description = "Every reach the bearer has is one tile shorter -- spell, bow and fist alike.",
    binds = true,
    depth = 3,
    fee = 140,
    rules = { abilityRange = -1 },
}
