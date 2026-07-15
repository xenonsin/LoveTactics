-- A conjured creature, reached only through a summon ability
-- (data/items/ability/ability_summon_wind_elemental.lua), which scales it by the item's upgrade level.
-- The scout: featherlight and blindingly fast (movement 6, speed 7), darting in with quick Gale Fists.
-- Frail, so it lives by never standing still. See data/characters/fire_elemental.lua.
return {
    name = "Wind Elemental",
    sprite = "assets/chars/wind_elemental.png",
    stats = {
        health = 22, mana = 0, stamina = 60,
        staminaRegen = 2,
        damage = 4, magicDamage = 10,
        defense = 2, magicDefense = 7,
        movement = 6,
        speed = 7,
    },
    startingItems = { "gale_fists" },
}
