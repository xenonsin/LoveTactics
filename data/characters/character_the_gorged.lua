-- THE GORGED, rung 4: a vampire that drank until it filled the room (Wrath's vampires, reviewed 2026-09-26/27; the
-- elite of The Gorged, on Wrath's seat floor). A human fighter under the vampire tag -- undead, Grave-Cold, the
-- Thirst -- grown to two tiles by two, slow, and full.
--
--   FULL TO BURSTING   every blow that wounds it spills a blood pool on a tile beside it. A vampire that steps in
--                      drinks it (Thirst reset, a heal); a living body that steps in Bleeds, to the Gorged.
--   THE BURST          at half health every tile within 1 floods, it shrinks to ONE tile, it moves faster, and it
--                      is in Bloodlust until it falls -- biting the nearest body, its own brood included.
--
-- The fight's question is where to stand: melee it and its pools ring the company; wade through them and every
-- step after feeds it. After the burst the slow wall is a fast, small thing in a flooded room.
--
-- Drops the Surfeit Heart: what it could not hold, worn as a shield.
return {
    name = "The Gorged",
    race = "human",
    tier = 4,
    class = "fighter",
    vampire = true,
    boss = true, -- off the execute and Charm tables, as every elite of the deeps is
    sprite = "assets/chars/the_gorged.png",
    archetype = "aggressive",
    -- FOUR TILES (the Chimera's, Avaritia's and the Thing Under the Seam's footprint) until it bursts.
    footprint = { w = 2, h = 2 },
    stats = {
        -- ~300 on its floor: the fighter table adds four a level, and floor 8 fields it at level 24 (probed).
        health = 210, mana = 0, stamina = 30,
        staminaRegen = 5,
        damage = 14, magicDamage = 0,
        defense = 5, magicDefense = 4,
        movement = 2, -- slow while it is full; the burst adds to it
        speed = 3,
        skill = 5, luck = 3,
    },
    startingItems = {
        "weapon_iron_axe",      "utility_full_to_bursting", "ability_feed",
        "ability_wing_swap",    false,                      false,
        false,                  false,                      false,
    },
    drops = { "utility_surfeit_heart" },
    defaultAction = "weapon_iron_axe",
    signatureWeapon = "weapon_iron_axe",
}
