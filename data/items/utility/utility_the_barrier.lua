-- THE BARRIER: the Bailiff's organ (data/characters/character_bailiff.lua; models/toll.lua). It braces at the end of
-- every turn, and its brace covers every Tollkeeper beside it until its next turn, so a line of them is a gate. Go
-- around the gate, or break the brace with impact (trait_barred, on every Tollkeeper's organ).
--
-- `always` because an AI body never presses Defend; `kin` because the gate is the Tollkeepers' and nobody else's.
-- Creature kit: bound, unstealable, on no shelf. Its drop, the Bailiff's Bar, is the same rule on a Defend.
return {
    name = "The Barrier",
    description = "Braces at the end of every turn, and Braces every Tollkeeper beside it until its next turn.",
    flavor = "One of them is a gatepost. A line of them is a gate.",
    sprite = "assets/items/utility_the_barrier.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_the_barrier" },
    traitParams = { always = true, kin = true, covers = 4, brace = 6 },
}
