-- BORN TO THE HEIGHT: the Elf Starcaller's organ (data/characters/character_elf_starcaller.lua). Approved 2026-09-30
-- ("Pride's Bestiary"). The spire's Exposure does nothing to it, and on it it casts for +3 Magic Damage from a tile
-- further out (trait_born_to_the_height). Bound and unstealable.
return {
    name = "Born to the Height",
    description = "Immune to Exposure. On it, increase magic damage by 3 and reach by 1.",
    flavor = "It reads the stars from the open span with its back to the drop.",
    sprite = "assets/items/utility_born_to_the_height.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_born_to_the_height" },
}
