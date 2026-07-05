-- Enemy character blueprint. See data/characters/bandit.lua for the shape.
return {
    name = "Wild Boar",
    sprite = "assets/chars/boar.png",
    stats = {
        health = 70, mana = 0, stamina = 40,
        damage = 14, magicDamage = 0,
        defense = 8, magicDefense = 1,
        movement = 3,
    },
    startingItems = { "fangs" },
}
