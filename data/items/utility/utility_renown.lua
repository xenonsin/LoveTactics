-- RENOWN: the Elf-Lord's organ (data/characters/character_elf_lord.lua). Approved 2026-09-30 ("Pride's Bestiary"),
-- as an aura: every kill an elf of his side makes gives him a stack of Renown, and every elf within 3 of him fights
-- for +1 Damage a stack (trait_renown). Bound and unstealable; the Laurel is what a company carries out.
return {
    name = "Renown",
    description = "Every kill an elf of your side makes gives you Renown. Elves within 3 gain damage for each.",
    flavor = "A herald walks two steps behind him and counts aloud.",
    sprite = "assets/items/utility_renown.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_renown" },
}
