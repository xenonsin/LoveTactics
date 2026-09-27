-- THE THRALL: the Blood-Ghoul's organ (Wrath's vampires, 2026-09-26). A living body kept to drink from: a vampire
-- beside it may Feed on it (ability_feed), and when it dies every living body beside it Bleeds (trait_thrall).
return {
    name = "Thrall",
    description = "A vampire beside it may drink from it. When it dies, every living body beside it Bleeds.",
    flavor = "Its neck and wrists are scabbed in neat rows where the drinking is done.",
    sprite = "assets/items/utility_thrall.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_thrall" },
}
