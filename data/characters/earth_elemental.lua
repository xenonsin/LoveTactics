-- A conjured creature, reached only through a summon ability
-- (data/items/ability/ability_summon_earth_elemental.lua), which scales it by the ability's summon power.
-- The tank of the set: the most health and armor, but slow, and it fights PHYSICALLY -- its Stone
-- Fists crush (and shatter the Frozen) rather than cast. See data/characters/fire_elemental.lua.
return {
    name = "Earth Elemental",
    sprite = "assets/chars/earth_elemental.png",
    stats = {
        health = 60, mana = 0, stamina = 60,
        staminaRegen = 2,
        damage = 12, magicDamage = 2,
        defense = 10, magicDefense = 6,
        movement = 3,
        speed = 2,
    },
    startingItems = { "stone_fists" },
}
