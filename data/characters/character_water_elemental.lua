-- A conjured creature, reached only through a summon ability
-- (data/items/ability/ability_summon_water_elemental.lua), which scales it by the item's upgrade level.
-- Sturdier and steadier than the fire elemental: more health, balanced defenses. Its Tide Fists leave
-- foes Wet. See data/characters/fire_elemental.lua for the blueprint shape.
return {
    name = "Water Elemental",
    sprite = "assets/chars/water_elemental.png",
    stats = {
        health = 28, mana = 0, stamina = 60,
        staminaRegen = 2,
        damage = 4, magicDamage = 11,
        defense = 4, magicDefense = 9,
        movement = 4,
        speed = 4,
    },
    startingItems = { "weapon_tide_fists" },
    -- Basic tactics (models/ai.lua): press the wounded -- finish the foe already closest to falling.
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
