-- Enemy character blueprint. The tough foe behind an `elite` encounter. See
-- data/characters/bandit.lua for the shape.
return {
    name = "Champion",
    sprite = "assets/chars/champion.png",
    stats = {
        health = 90, mana = 20, stamina = 70,
        damage = 20, magicDamage = 6,
        defense = 12, magicDefense = 8,
        movement = 3,
        speed = 3,
    },
    startingItems = { "weapon_iron_sword" },
}
