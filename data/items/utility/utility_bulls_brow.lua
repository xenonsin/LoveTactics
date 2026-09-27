-- BULL'S BROW: the Run in a player's hand (data/traits/trait_the_run.lua; "The Minotaur", 2026-09-26/27), and one
-- of the two things the Minotaur drops. Move two or more tiles in a straight line and then strike hand to hand,
-- and the body struck is driven back a tile for every two you ran, up to 3.
--
-- A shove that comes free with a blow, paid for with a straight approach. A Vanguard's: it is the other half of
-- the Breaker's Harness, which Stuns whatever a stopped shove slams into. An unstocked trophy on floor eight's
-- rung.
return {
    name = "Bull's Brow",
    description = "Move 2+ tiles in a straight line, then strike: the foe is driven back 1 tile for every 2 run, up to 3.",
    flavor = "Lower the head and keep the line. Whatever is at the end of it stops being there.",
    sprite = "assets/items/utility_bulls_brow.png",
    type = "utility",
    tags = { "physical" },
    class = "vanguard",
    unlockLevel = 8,
    unstocked = true,
    traits = { "trait_the_run" },
}
