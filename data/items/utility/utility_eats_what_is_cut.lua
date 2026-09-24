-- IT EATS WHAT YOU CUT OFF: the Chimera's lion eating its own broken head (trait_eats_what_is_cut).
-- Creature kit only, and no drop -- the man-eater's reasoning: the one thing Gluttony will not hand a
-- company is the habit of eating its own.
return {
    name = "It Eats What You Cut Off",
    description = "When one of its heads is broken, it eats it: heals 15 and is Gorged.",
    flavor = "Waste not.",
    sprite = "assets/items/utility_eats_what_is_cut.png",
    type = "utility",
    class = "creature",
    tags = { "beast" },
    noSteal = true,
    traits = { "trait_eats_what_is_cut" },
}
