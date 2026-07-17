-- Enemy character blueprint. A pack leader that joins wolf encounters at higher
-- prestige. See data/characters/bandit.lua for the shape.
return {
    name = "Alpha Wolf",
    sprite = "assets/chars/wolf_alpha.png",
    stats = {
        health = 80, mana = 0, stamina = 80,
        damage = 16, magicDamage = 0,
        defense = 6, magicDefense = 3,
        movement = 5,
        speed = 6, -- fastest in the pack
    },
    startingItems = { "weapon_fangs", "utility_feral_instinct" },
}
