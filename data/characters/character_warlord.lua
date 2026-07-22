-- Enemy boss blueprint (quest objective). See data/characters/bandit.lua.
return {
    name = "The Warlord",
    boss = true, -- a quest objective: immune to execute (Coup de Grace) and to Charm
    sprite = "assets/chars/warlord.png",
    stats = {
        health = 155, mana = 20, stamina = 100,
        damage = 28, magicDamage = 8,
        defense = 16, magicDefense = 10,
        movement = 3,
        speed = 2, -- heavy
    },
    startingItems = { "weapon_iron_sword" },
    -- Basic tactics (models/ai.lua): press the wounded -- finish the foe already closest to falling.
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
