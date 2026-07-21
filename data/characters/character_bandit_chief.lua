-- Enemy boss blueprint (quest objective). See data/characters/bandit.lua.
return {
    name = "Bandit Chief",
    boss = true, -- a quest objective: immune to execute (Coup de Grace) and to Charm
    sprite = "assets/chars/bandit_chief.png",
    stats = {
        health = 105, mana = 0, stamina = 80,
        damage = 22, magicDamage = 0,
        defense = 12, magicDefense = 6,
        movement = 3,
        speed = 4,
    },
    startingItems = { "weapon_iron_sword" },
}
