-- DEAD WEIGHT: it is heavier than it has any business being, and it is not going anywhere.
--
-- ONE TILE OF MOVEMENT, which is a quarter of an ordinary body's four (data/characters/) and is felt on
-- the first turn of every fight rather than in a number nobody reads. Movement is deliberately the stat
-- this one takes, because it is the stat a player experiences as the BOARD rather than as arithmetic:
-- the flank you could make last floor is a flank you cannot make now.
--
-- IT IS FLOORED AT ZERO BY THE ENGINE, not here (Combat.moveRange's clamp, which exists because armour
-- movement penalties already stack). A body under two of these walks nowhere rather than backwards.
return {
    name = "Dead Weight",
    description = "-1 movement, and the piece cannot be moved, stowed, sold or taken from you.",
    binds = true,
    depth = 1,
    bonus = { movement = -1 },
}
