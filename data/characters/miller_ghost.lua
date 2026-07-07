-- Enemy boss blueprint (quest objective). See data/characters/bandit.lua.
return {
    name = "The Miller's Ghost",
    sprite = "assets/chars/miller_ghost.png",
    stats = {
        health = 140, mana = 60, stamina = 50,
        damage = 8, magicDamage = 22,
        defense = 8, magicDefense = 14,
        movement = 4,
        speed = 4,
    },
    startingItems = { "flame_gem" },
}
