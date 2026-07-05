-- Enemy boss blueprint (quest objective). See data/characters/bandit.lua.
return {
    name = "Bandit Chief",
    sprite = "assets/chars/bandit_chief.png",
    stats = {
        health = 150, mana = 0, stamina = 80,
        damage = 22, magicDamage = 0,
        defense = 12, magicDefense = 6,
        movement = 3,
    },
    startingItems = { "iron_sword" },
}
