-- Enemy boss blueprint (quest objective). See data/characters/bandit.lua.
return {
    name = "Bandit Chief",
    boss = true, -- a quest objective: immune to execute (Coup de Grace) and to Charm
    sprite = "assets/chars/bandit_chief.png",
    stats = {
        health = 105, mana = 0, stamina = 20,
        damage = 22, magicDamage = 0,
        defense = 12, magicDefense = 6,
        movement = 3,
        speed = 4,
    },
    startingItems = { "weapon_iron_sword" },
    -- Basic tactics (models/ai.lua): press the wounded -- finish the foe already closest to falling.
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
