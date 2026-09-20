-- THE HOLLOW: there is half as much of the bearer as there was.
--
-- `rules.halveMaxHealth = 2` -- the divisor The Whetted Vow pays for its doubled damage, with nothing
-- bought. The bluntest thing on the ladder, which is right for a floor-twelve find: by then the player
-- has met nine milder hexes and knows exactly what the room costs.
--
-- THE AXIS THE DEEP END WAS MISSING. The Anchor takes the legs, The Shut Hand takes the recovery, and
-- neither touches the pool itself -- so a company could be very deep and still be fielding bodies that
-- simply do not die. This is the one that makes a floor-twelve fight frightening rather than tedious.
--
-- IT READS CLEAN BESIDE A WOUND, which is worth stating because the two look alike and are not. A wound
-- RESERVES a share of the pool and cannot be healed into (models/wound.lua); this HALVES the pool the
-- reservation is taken from. They stack the way two different subtractions stack, and a wounded body
-- under this is in real trouble -- which is the correct reading of carrying both.
return {
    name = "The Hollow",
    description = "The bearer's health pool is half the size it was.",
    binds = true,
    depth = 12,
    fee = 340,
    rules = { halveMaxHealth = 2 },
}
