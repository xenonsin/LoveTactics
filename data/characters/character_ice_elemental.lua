-- A conjured creature, reached only through a summon ability
-- (data/items/ability/ability_summon_ice_elemental.lua), which scales it by the item's upgrade level.
-- Slow and hardy, a wall of ice: high magic defense, steady magic damage through its Frost Fists.
-- See data/characters/fire_elemental.lua for the blueprint shape.
return {
    name = "Ice Elemental",
    sprite = "assets/chars/ice_elemental.png",
    stats = {
        health = 44, mana = 0, stamina = 60,
        staminaRegen = 2,
        damage = 4, magicDamage = 12,
        defense = 5, magicDefense = 12,
        movement = 3,
        speed = 3,
    },
    startingItems = { "weapon_frost_fists" },
}
