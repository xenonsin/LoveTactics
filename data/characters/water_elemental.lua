-- A conjured creature, reached only through a summon ability
-- (data/items/ability/ability_summon_water_elemental.lua), which scales it by the ability's Power.
-- Sturdier and steadier than the fire elemental: more health, balanced defenses. Its Tide Fists leave
-- foes Wet. See data/characters/fire_elemental.lua for the blueprint shape.
return {
    name = "Water Elemental",
    sprite = "assets/chars/water_elemental.png",
    stats = {
        health = 40, mana = 0, stamina = 60,
        staminaRegen = 2,
        damage = 4, magicDamage = 11,
        defense = 4, magicDefense = 9,
        movement = 4,
        speed = 4,
    },
    startingItems = { "tide_fists" },
}
