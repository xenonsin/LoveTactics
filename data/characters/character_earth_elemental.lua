-- A conjured creature, reached only through a summon ability
-- (data/items/ability/ability_summon_earth_elemental.lua), which scales it by the item's upgrade level.
-- The tank of the set: the most health and armor, but slow, and it fights PHYSICALLY -- its Stone
-- Fists crush (and shatter the Frozen) rather than cast. See data/characters/fire_elemental.lua.
return {
    name = "Earth Elemental",
    kind = "elemental",
    tier = 2,
    sprite = "assets/chars/earth_elemental.png",
    stats = {
        health = 42, mana = 0, stamina = 15,
        staminaRegen = 2,
        damage = 12, magicDamage = 2,
        defense = 10, magicDefense = 6,
        movement = 4,
        speed = 2,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 3, luck = 6,
    },
    startingItems = { "weapon_stone_fists" },
    -- Basic tactics (models/ai.lua): the wall still finishes what it can reach -- press the foe closest
    -- to falling.
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
