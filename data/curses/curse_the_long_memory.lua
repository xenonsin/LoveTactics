-- THE LONG MEMORY: nothing the enemy does to the bearer ever wears off.
--
-- `rules.statusesPersist` -- The Open Wound's bargain, arriving unasked. Every debuff that lands holds
-- for the rest of the fight: the bleed, the cripple, the blind, the mire, the acid. Nothing ticks down.
--
-- IT IS ALREADY SAFE, AND THE CARVE-OUT IS WRITTEN AND ARGUED. models/status.lua's tick exempts anything
-- flagged `disablesReactions` -- Stun, Freeze, and any future Sleep -- for the reason it states at
-- length: "a permanent disable is just the fight being over for somebody". So this can never become a
-- lock. Everything it DOES keep is something a body can still fight through, which is what makes it a
-- steep price rather than a deletion.
--
-- THE DEEPEST HEX THAT IS STILL A FIGHT. Below this the rift starts taking pools and legs; this takes
-- the assumption every player has that a bad turn ends. A company that has learned to shrug off the
-- first Crippled because it lapses in six ticks has to re-learn the whole fight around one body.
return {
    name = "The Long Memory",
    description = "Every debuff the enemy lands on the bearer lasts the rest of the fight.",
    binds = true,
    depth = 10,
    fee = 300,
    rules = { statusesPersist = true },
}
