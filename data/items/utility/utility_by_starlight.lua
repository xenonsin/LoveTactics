-- BY STARLIGHT: the Elf Starcaller's organ (data/characters/character_elf_starcaller.lua). Reworked 2026-10-01 off
-- Born to the Height (see trait_by_starlight for why). Its spells strike a Limned foe for 3 more, and while any foe
-- is Limned it casts a tile further out. Bound and unstealable.
return {
    name = "By Starlight",
    description = "Your spells deal 3 more damage to a Limned foe. While any foe is Limned, your reach grows by 1.",
    flavor = "It does not aim at you. It aims at the light on you, which is easier to see.",
    sprite = "assets/items/utility_by_starlight.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_by_starlight" },
}
