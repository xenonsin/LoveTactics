-- THE LAUREL OF RENOWN: the Elf-Lord's drop (data/characters/character_elf_lord.lua). Approved 2026-09-30 ("Pride's
-- Bestiary"). His Renown in a company's hands: a kill by the wearer or any ally lays a stack of Laurels (+1 Damage,
-- up to 5, for the fight) on the wearer and every ally within 3 (trait_laurel_of_renown). On the warlord's rack,
-- where the banners and the rallies are: it is tempo for the line, earned by the line.
--
-- `unstocked`: the body's own piece, visible on the rack and never sold (docs/drops.md).
return {
    name = "Laurel of Renown",
    description = "When you or an ally makes a kill, you and allies within 3 gain +1 damage, up to 5, for the fight.",
    flavor = "A wreath of gilded bay leaves, one leaf for every body the court has felled.",
    sprite = "assets/items/utility_laurel_of_renown.png",
    type = "utility",
    tags = { "charm" },
    class = "warlord",
    unlockLevel = 13,
    unstocked = true,
    traits = { "trait_laurel_of_renown" },
}
