-- WOUNDED PRIDE: the elf court's organ (models/elf_court.lua; the creature identity pass, 2026-11-19). Carried by the
-- court's own elves -- the Longbow, the Bladedancer, the Highborn and the Starcaller -- and not by the race, so a hired
-- elf and an adventurer elf are not compelled by it. The court's lords (the Elf-Lord, Sublimitas, the Wishmaker) do
-- not carry it either: a boss whose whole kit is put aside for two turns is a boss with no fight.
--
-- `bound`, `noSteal`, `class = "creature"`: a creature's organ is never handed to the player.
return {
    name = "Wounded Pride",
    description = "The blow that ends its Unblemished Taunts it onto the striker for 2 turns.",
    flavor = "Pride does not forget a face. It has four hundred years to remember it in.",
    sprite = "assets/items/utility_wounded_pride.png",
    type = "utility",
    class = "creature",
    tags = { "natural" },
    bound = true,
    noSteal = true, -- a creature's body is not loot
    traits = { "trait_wounded_pride" },
}
