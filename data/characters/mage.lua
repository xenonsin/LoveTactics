return {
    name = "Mage",
    sprite = "assets/chars/mage.png",
    stats = {
        health = 60, mana = 80, stamina = 40, -- resource stats
        staminaRegen = 1, -- stamina recovered per elapsed tick (a flat stat, not a resource)
        damage = 5, magicDamage = 18,          -- flat stats
        defense = 4, magicDefense = 12,
        movement = 3, -- number of spaces this character can move
        speed = 3,    -- initiative tie-break; folded into starting initiative
    },
    -- healing_potion stays first (its default weapon / basic-attack ordering is unchanged).
    -- The trap kit now lives on the archer; the mage keeps Jolt as its status-system spell.
    -- Fire Stone infuses adjacent weapons/abilities with fire + Burn; packed next to Fireball it
    -- makes the mage's spells set foes alight (see fire_stone.lua).
    startingItems = { "healing_potion"
    , "ability_jolt"
    , "silk_robes"
    , "parasitic_staff"
    , "ability_fireball"
    , "fire_stone"
    , "ability_rain" }, -- item ids
}
