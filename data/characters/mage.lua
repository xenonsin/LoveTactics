return {
    name = "Mage",
    sprite = "assets/chars/mage.png",
    -- Innate growth class: the fallback/tie-break for the level-up growth system (models/growth.lua).
    class = "mage",
    stats = {
        health = 60, mana = 80, stamina = 40, -- resource stats
        staminaRegen = 1, -- stamina recovered per elapsed tick (a flat stat, not a resource)
        damage = 5, magicDamage = 18,          -- flat stats
        defense = 4, magicDefense = 12,
        movement = 3, -- number of spaces this character can move
        speed = 3,    -- initiative tie-break; folded into starting initiative
    },
    -- Innate: casts through its own life when the mana runs dry (data/traits/overchannel.lua).
    traits = { "overchannel" },
    -- healing_potion stays first (its default weapon / basic-attack ordering is unchanged).
    -- The trap kit now lives on the archer; the mage keeps Jolt as its status-system spell.
    -- Fire Stone infuses adjacent weapons/abilities with fire + Burn; packed next to Fireball it
    -- makes the mage's spells set foes alight (see fire_stone.lua).
    -- Summon Fire Elemental reserves a quarter of that deep mana pool for as long as the elemental
    -- stands, so a summoning mage fights the rest of the battle on three-quarters of its magic.
    startingItems = { "healing_potion"
    , "ability_jolt"
    , "silk_robes"
    , "parasitic_staff"
    , "ability_fireball"
    , "fire_stone"
    , "ability_rain"
    , "ability_summon_fire_elemental" }, -- item ids
}
