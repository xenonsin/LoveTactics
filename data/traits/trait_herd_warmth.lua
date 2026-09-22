-- HERD WARMTH: animals that stand together heal, and animals that get separated do not.
--
-- THE HEALING HALF OF AN ADJACENCY FAMILY THAT WAS MISSING ONE. Two traits already measure who is
-- standing beside you and pay for it, continuously, off the live board:
--
--   trait_formation_fighter   defense per adjacent ally -- a closed line SURVIVES
--   trait_close_ranks         damage  per adjacent ally -- a closed line THREATENS
--   this                      health while ANY ally is adjacent -- a closed line KEEPS
--
-- Nothing healed. That gap is why this is a new rule rather than a third number on an old one, and it
-- is what makes the Meandering Stag's premise expressible one rung down without borrowing any of it:
-- the apex is the enemy HEALER and does it by walking (its trail is the whole first half of that
-- fight). This does it by STANDING, which is the opposite verb, and it is worth nothing at all to an
-- animal on its own.
--
-- WHICH IS THE POINT ON THE ROAD, and it is now the only point. There were two stag encounters -- a
-- lone animal and data/encounters/encounter_the_herd.lua -- and they fielded one CAST at two counts,
-- which is a fight met twice rather than two fights. The lone stop is deleted. This rule is what made
-- that free: it pays nothing at all to an animal on its own, so the deleted stop was the one place in
-- the game where this trait was guaranteed to be worth zero, and the surviving one is the reason it
-- exists -- a herd is not four copies of the road fight. Break them apart, or put one down before the
-- others close.
--
-- FLAT, NOT PER-ALLY, and this is a tuning decision worth stating because the two traits above both
-- scale. A stag in the middle of four would be healing three times over, which on a fight already
-- carrying a recorded overrun (tests/support/slow_road_fights.lua) is an attrition sink rather than a
-- decision. One ally beside you is the whole condition; the fourth is worth what the first is.
--
-- A PURE MARKER WITH NO HOOKS, exactly like data/traits/trait_sanctified_presence.lua and for the same
-- reason it gives: recovery lives in the recovery loop (Combat.regenerate reads this by name), because
-- a trait has no per-tick hook and models/trait.lua argues at length that it should not have one. A
-- status would put a countdown on the badge row instead, which would be a lie -- there is no clock
-- here, only a neighbour.
return {
    name = "Herd Warmth",
    description = "Recovers health each tick while at least one ally stands beside you.",
}
