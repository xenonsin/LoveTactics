-- A conjured creature, reached only through a summon ability
-- (data/items/ability/ability_summon_lightning_elemental.lua), which scales it by the ability's summon power.
-- Glass cannon: frail, but the hardest-hitting of the elementals and fast on its feet. Its Storm Fists
-- reap the bonus on a Wet foe. See data/characters/fire_elemental.lua for the blueprint shape.
return {
    name = "Lightning Elemental",
    sprite = "assets/chars/lightning_elemental.png",
    stats = {
        health = 24, mana = 0, stamina = 60,
        staminaRegen = 2,
        damage = 4, magicDamage = 16,
        defense = 2, magicDefense = 8,
        movement = 5,
        speed = 6,
    },
    startingItems = { "storm_fists" },
}
