-- THE TETHER: the bearer's wounds are not only theirs.
--
-- A quarter of every wound splashes onto the nearest ally (data/traits/trait_tether.lua). The only hex in
-- the game that touches POSITION, and the reason the set needed one: everything else here is a number on
-- a sheet, and this is a rule about where four bodies may stand.
--
-- IT FIGHTS THE WHOLE SHAPE OF A COMPANY. Adjacency is what this game is built on -- the guard redirects,
-- the auras, the censers, the line that holds a chokepoint together -- and a body under this has to fight
-- at arm's length from all of it. The player does not lose a stat; they lose the formation.
--
-- BINDS, because the answer is meant to be spatial rather than administrative. Left loose it would simply
-- be shelved, and the interesting version is the one where a knight has to learn to fight alone for two
-- trips.
--
-- THE SPLASH IS A SHARE AND NOT A FLAT FIGURE, so it scales with the blow rather than with the floor: a
-- scratch splashes a scratch, and the boss's opener is what makes the player think about it.
return {
    name = "The Tether",
    description = "A quarter of every wound the bearer takes is dealt to the nearest ally.",
    binds = true,
    depth = 7,
    fee = 230,
    traits = { "trait_tether" },
}
