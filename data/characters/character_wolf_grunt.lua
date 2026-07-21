-- Enemy character blueprint. See data/characters/bandit.lua for the shape.
return {
    name = "Wolf",
    sprite = "assets/chars/wolf.png",
    stats = {
        health = 28, mana = 0, stamina = 70,
        damage = 10, magicDamage = 0,
        defense = 3, magicDefense = 2,
        movement = 5, -- fast, low health
        speed = 5,
    },
    startingItems = { "weapon_fangs", "utility_feral_instinct" },
}
