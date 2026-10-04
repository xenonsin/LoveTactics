-- THE YUKI-ONNA, rung 3: the snow woman who breathes on travellers until they sleep ("Sloth's Bestiary",
-- 2026-10-04, approved). Sloth's approach.
--
--   SNOW-SLEEP   a foe that ends its turn within 3 of her without having moved gains Drowsy; at 3 Drowsy it falls
--                Asleep (utility_snow_sleep, trait_snow_sleep; Drowsy is the foundation's status_drowsy).
--   HER KISS     on a sleeper it deals double and does not wake it (weapon_snow_kiss).
--   COUNTER      keep moving -- or wake the sleeper yourself: a Cure, or a blow that catches it.
--
-- AN ONI, AS A YOKAI: the race grants the Horn and the Witch's Taint (data/races/oni.lua). How they sit on her: the
-- Horn comes out when she is wounded to half, and sends her at whoever did it -- which pulls her off her ground,
-- so a company that hurts her badly enough gets her walking into it; and a critical hit snaps the horn and takes
-- every mana cast off her, which is her Kiss (paid in mana). Her Snow-Sleep is no cast and keeps breathing. The
-- Taint makes a hexed foe her first kiss.
--
-- She drops White Silence, on the elementalist table. A mage in the silk the Arcanum wears, on the mage table.
return {
    name = "Yuki-onna",
    race = "oni",
    tier = 3,
    class = "mage",
    sprite = "assets/chars/yuki_onna.png",
    archetype = "aggressive",
    stats = {
        health = 92, mana = 42, stamina = 14,
        staminaRegen = 2, manaRegen = 4,
        damage = 4, magicDamage = 11,
        defense = 2, magicDefense = 7,
        movement = 5, -- the silk takes one
        speed = 5,
        skill = 5, luck = 5,
    },
    startingItems = {
        "weapon_snow_kiss", "utility_snow_sleep", "armor_silk_robes",
        false,              false,                false,
        false,              false,                false,
    },
    drops = { "utility_white_silence" },
    defaultAction = "weapon_snow_kiss",
    signatureWeapon = "weapon_snow_kiss",
    -- The sleeper first: a body under is a body she kisses for double, and it stays under.
    ai = {
        { priority = "high", act = "attack", targetPref = "sleeping",
          when = { subject = "any_foe", test = "has_status", value = "status_sleep" } },
    },
}
