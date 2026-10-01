-- UNTOUCHABLE: the Elf Bladedancer's organ (data/characters/character_elf_bladedancer.lua). Approved 2026-09-30
-- ("Pride's Bestiary"). While Unblemished, every attack that rolls to hit is evaded (trait_untouchable). Bound and
-- unstealable: what it is, not what it carries.
return {
    name = "Untouchable",
    description = "While Unblemished, evade every attack that rolls to hit.",
    flavor = "It does not parry and it does not block; it is simply not where the blade arrives.",
    sprite = "assets/items/utility_untouchable.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_untouchable" },
}
