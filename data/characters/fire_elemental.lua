-- A conjured creature, not a recruitable one: reached only through a summon ability
-- (data/items/ability/ability_summon_fire_elemental.lua), which scales it by the ability's Power.
-- Frail and slow, but it hits hard through magicDefense and shrugs off spells. Like the beasts, it
-- carries a natural weapon rather than crafted gear, and no mana of its own -- its summoner already
-- paid for it. See data/characters/bandit.lua for the blueprint shape.
return {
    name = "Fire Elemental",
    sprite = "assets/chars/fire_elemental.png",
    stats = {
        health = 30, mana = 0, stamina = 60,
        staminaRegen = 2,
        damage = 4, magicDamage = 14,
        defense = 2, magicDefense = 10,
        movement = 4,
        speed = 4,
    },
    startingItems = { "flame_fists" },
}
