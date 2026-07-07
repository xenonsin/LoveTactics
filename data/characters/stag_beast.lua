-- Enemy character blueprint. See data/characters/bandit.lua for the shape.
return {
    name = "Ancient Stag",
    sprite = "assets/chars/stag.png",
    stats = {
        health = 90, mana = 30, stamina = 60,
        damage = 10, magicDamage = 12,
        defense = 7, magicDefense = 9,
        movement = 4,
        speed = 5,
    },
    startingItems = { "fangs" },
}
