-- A conjured creature, not a recruitable one: reached only through a summon ability
-- (data/items/ability/ability_summon_fire_elemental.lua), which scales it by the item's upgrade level.
-- Frail and slow, but it hits hard through magicDefense and shrugs off spells. Like the beasts, it
-- carries a natural weapon rather than crafted gear, and no mana of its own -- its summoner already
-- paid for it. See data/characters/bandit.lua for the blueprint shape.
return {
    name = "Fire Elemental",
    sprite = "assets/chars/fire_elemental.png",
    stats = {
        health = 22, mana = 0, stamina = 60,
        staminaRegen = 2,
        damage = 4, magicDamage = 14,
        defense = 2, magicDefense = 10,
        movement = 4,
        speed = 4,
    },
    startingItems = { "weapon_flame_fists" },
    -- Basic tactics (models/ai.lua): a summoned brawler earns its keep -- press the foe closest to falling.
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
