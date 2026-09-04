-- A conjured creature, reached only through a summon ability
-- (data/items/ability/ability_summon_water_elemental.lua), which scales it by the item's upgrade level.
-- Sturdier and steadier than the fire elemental: more health, balanced defenses. Its Tide Fists leave
-- foes Wet. See data/characters/fire_elemental.lua for the blueprint shape.
return {
    name = "Water Elemental",
    kind = "elemental",
    tier = 1,
    sprite = "assets/chars/water_elemental.png",
    stats = {
        health = 28, mana = 0, stamina = 15,
        staminaRegen = 2,
        damage = 4, magicDamage = 11,
        defense = 4, magicDefense = 9,
        movement = 4,
        speed = 4,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 2, luck = 6,
    },
    -- INNATE MITIGATION (models/character.lua `resist`), in the same unit an armour's resist
    -- table is written in and summed into the same total. This body wears nothing, so this is
    -- what it has instead of a coat -- and the negative line is not an oversight, it is the
    -- price. See docs/bestiary.md, "What a creature wears instead of armour".
    --   A blow lands in water and water is what happens to a blow that lands in water.
    --   An edge shears the column apart. Cold and current do worse than that.
    resist = { water = 2, impact = 2, slash = -2, lightning = -4, ice = -4 },
    startingItems = { "weapon_tide_fists" },
    -- Basic tactics (models/ai.lua): press the wounded -- finish the foe already closest to falling.
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
