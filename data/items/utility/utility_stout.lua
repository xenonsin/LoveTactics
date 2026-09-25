-- STOUT: what a dwarf IS, granted by its race (data/races/dwarf.lua) into the first free cell of every
-- dwarf ever minted, the way the naga's coils are.
--
-- THREE RULES AND AN INHERITANCE, reviewed 2026-09-24 ("The Dwarves of Greed" artifact):
--   * it cannot be moved -- The Unheld's own rule (trait_nothing_to_hold), worn as a body rather than a
--     charm. REFUSING TO LET GO, said as a stance.
--   * it cannot be robbed -- `wardsTheft` (trait_stout), which Combat.steal and Combat.strip both ask
--     before they reach into a grid. A thief's blow and a Velvet Slime's strip come back empty-handed.
--   * it goes for loose gold -- `seeksHeaps` (trait_stout): a coin heap reads as friendly ground to its
--     planner (hazard_coin_heap's `welcomes`), and a dwarf with nothing to hit walks for the nearest one.
--   * its Share passes on when it falls (trait_inheritance) -- the last dwarf standing is the richest.
--
-- BOUND AND UNSTEALABLE, the honest split between an organ and a piece of kit: this never comes off a
-- corpse. The Unheld is still sold at the bulwark's counter, so the shove half is not lost to a player
-- who wants it; the rest is what being a dwarf costs a grid cell for.
return {
    name = "Stout",
    description = "You cannot be moved or robbed. Loose gold draws you, and a fallen dwarf's Share passes to you.",
    flavor = "Put a hand on a dwarf's purse and see how much of the dwarf comes with it.",
    sprite = "assets/items/utility_stout.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_nothing_to_hold", "trait_stout", "trait_inheritance" },
}
