-- THE ALPHA WYVERN: the Wyvern, and the whole flight rides its wind (utility_lead_the_wind -- every wyvern
-- within three is +15 Avoid on top of its Tailwind, and keeps it with a foe beside it). The Alpha Wolf's
-- lesson told in wind: the flight is harder to hit with it alive, so the correct play is to Mark it, Root
-- it, or bring it down first -- and it is gone the instant the alpha falls or goes Aloft itself.
--
-- It holds back: it takes wing the moment anything comes within two tiles, where the line waits for one.
return {
    name = "Alpha Wyvern",
    race = "beast",
    tier = 2,
    palate = "ability_take_wing", -- what Gula takes when she eats one (models/palate.lua)
    sprite = "assets/chars/wyvern_alpha.png",
    stats = {
        health = 54, mana = 0, stamina = 24,
        staminaRegen = 3,
        damage = 15, magicDamage = 0,
        defense = 5, magicDefense = 4,
        movement = 5,
        speed = 7, -- first in the flight
        skill = 5, luck = 8,
    },
    resist = { slash = 3, impact = -3, wind = 3 },
    startingItems = {
        "weapon_wind_shear",       "ability_take_wing",      "utility_tailwind",
        "utility_lead_the_wind",   "utility_manticore_wings", "utility_feral_instinct",
        false,                     false,                    false,
    },
    drops = { "utility_tailwind_charm" },
    defaultAction = "weapon_wind_shear",
    archetype = "skirmish",
    ai = {
        { priority = "high", act = "cast", item = "ability_take_wing",
          when = { subject = "nearest_foe", test = "within", value = 2 } },
        { act = "cast", item = "ability_take_wing",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
