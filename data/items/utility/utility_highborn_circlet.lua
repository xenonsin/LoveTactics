-- THE HIGHBORN CIRCLET: the Elf Highborn's drop (data/characters/character_elf_highborn.lua). Approved 2026-09-30
-- ("Pride's Bestiary"). Will Not Admit the Wound, worn: a full round without being struck heals 15% and makes the
-- wearer Composed, +2 Damage until struck (trait_highborn_circlet).
--
-- `unstocked`: the body's own piece, visible on the knight's rack and never sold (docs/drops.md).
return {
    name = "Highborn Circlet",
    description = "If you go a full round without being struck, heal 15% and gain +2 damage until you are struck.",
    flavor = "A thin silver band set with one cold blue stone, sized for a brow held level.",
    sprite = "assets/items/utility_highborn_circlet.png",
    type = "utility",
    tags = { "charm" },
    class = "knight",
    unlockLevel = 13,
    unstocked = true,
    traits = { "trait_highborn_circlet" },
}
