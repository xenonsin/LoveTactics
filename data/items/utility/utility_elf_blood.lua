-- UNBLEMISHED: what an elf IS, granted by its race (data/races/elf.lua) into the first free cell of every elf
-- ever minted, the way a goblin's Blood Feud is. Reviewed 2026-09-30 ("Pride's Bestiary").
--
-- The bearer opens every fight Unblemished (trait_unblemished -> status_unblemished): +4 Damage, +4 Magic
-- Damage, +8 Luck and +1 reach, until the first blow that draws its blood. Bound and unstealable.
return {
    name = "Unblemished",
    description = "Open every fight Unblemished. The first blow that wounds you ends it, and no heal restores it.",
    flavor = "An elf is perfect exactly once. Most of them spend the rest of the fight looking for whoever ended it.",
    sprite = "assets/items/utility_elf_blood.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_unblemished" },
}
