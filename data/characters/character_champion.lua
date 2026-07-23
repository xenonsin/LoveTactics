-- Enemy character blueprint. The tough foe behind an `elite` encounter. See
-- data/characters/bandit.lua for the shape.
return {
    name = "Champion",
    sprite = "assets/chars/champion.png",
    stats = {
        health = 90, mana = 20, stamina = 18,
        damage = 20, magicDamage = 6,
        defense = 12, magicDefense = 8,
        movement = 4,
        speed = 3,
    },
    startingItems = { "weapon_iron_sword" },
    -- Basic tactics (models/ai.lua): press the wounded -- finish the foe already closest to falling.
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
