-- What the CALDERA KING is (data/characters/character_caldera_king.lua): the Cinder Body crowned -- its trail of
-- fire (trait_cinder_trail), and it comes apart into three cinder slimes that each lay their own (trait_split).
-- So a King put down in the middle of the company is three fires walking in three directions.
--
-- Its pieces arrived already Seething until the creature identity pass (2026-11-19) moved Wrath's slimes off
-- Boil Over (see utility_cinder_body).
return {
    name = "Caldera Heart",
    description = "Voids blades, points and blows. Every tile it steps through catches Fire. Divides into three cinder slimes.",
    flavor = "It was a mountain once. Most of it still is.",
    sprite = "assets/items/caldera_heart.png",
    type = "utility",
    class = "creature",
    tags = { "relic" },
    bound = true,
    noSteal = true, -- a creature's body is not loot
    immune = { physical = true, slash = true, pierce = true, impact = true },
    traits = { "trait_adaptive", "trait_cinder_trail", "trait_split" },
    traitParams = { spawn = "character_cinder_slime", health = 26 },
}
