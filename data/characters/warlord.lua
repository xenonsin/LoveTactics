-- Enemy boss blueprint (quest objective). See data/characters/bandit.lua.
return {
    name = "The Warlord",
    sprite = "assets/chars/warlord.png",
    stats = {
        health = 220, mana = 20, stamina = 100,
        damage = 28, magicDamage = 8,
        defense = 16, magicDefense = 10,
        movement = 3,
    },
    startingItems = { "iron_sword" },
}
