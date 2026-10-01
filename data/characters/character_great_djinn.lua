-- THE GREAT DJINN: what the Wishmaker becomes on her third wish (models/djinn.lua). Reviewed 2026-09-30 ("Pride's
-- Bestiary"). Never dealt by any encounter: it is reached only through models/transform.lua, which keeps her
-- wounds, statuses and pools and takes this body's kit and flat stats.
--
-- Every djinn's spell at once -- the gale, the flame and the tide -- and Will Not Stoop, granted by the race. She
-- turns at 1 health under Lamp-Bound, so the tide is her way back up: every Wet foe on the board is health. While
-- the Lamp stands she cannot be killed; the company that has not broken it by now has to.
--
-- Tier 3, on the neutral table (an elemental has no shelf), and no drops of its own: Spoils pays from the Wishmaker's list.
return {
    name = "Great Djinn",
    race = "djinn",
    tier = 3,
    sprite = "assets/chars/great_djinn.png",
    archetype = "skirmish",
    unarmed = false, -- it casts; it never swings (Will Not Stoop)
    stats = {
        health = 130, mana = 70, stamina = 12,
        staminaRegen = 2, manaRegen = 6,
        damage = 0, magicDamage = 15,
        defense = 4, magicDefense = 9,
        movement = 5,
        speed = 4,
        skill = 6, luck = 6,
    },
    --   All three elements in one body, and the weight of none of them: a hammer still drives it back.
    resist = { fire = 3, water = 3, wind = 3, slash = 1, pierce = 1, impact = -2 },
    startingItems = {
        "ability_ifrits_flame", "ability_marids_flood", "ability_djinnis_breath",
        false,                  false,                 false,
        false,                  false,                 false,
    },
    defaultAction = "ability_ifrits_flame",
}
