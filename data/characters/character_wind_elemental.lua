-- A conjured creature, reached only through a summon ability
-- (data/items/ability/ability_summon_wind_elemental.lua), which scales it by the item's upgrade level.
-- The scout: featherlight and blindingly fast (movement 6, speed 7), darting in with quick Gale Fists.
-- Frail, so it lives by never standing still. See data/characters/fire_elemental.lua.
return {
    name = "Wind Elemental",
    kind = "elemental",
    tier = 1,
    sprite = "assets/chars/wind_elemental.png",
    stats = {
        health = 16, mana = 0, stamina = 15,
        staminaRegen = 2,
        damage = 4, magicDamage = 10,
        defense = 2, magicDefense = 7,
        movement = 6,
        speed = 7,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 2, luck = 6,
    },
    startingItems = { "weapon_gale_fists" },
    -- Basic tactics (models/ai.lua): the scout darts in on the weakest -- press the foe closest to falling.
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
