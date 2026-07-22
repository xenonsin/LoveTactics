-- Enemy character blueprint. See data/characters/bandit.lua for the shape.
return {
    name = "Ancient Stag",
    boss = true, -- a quest objective: immune to execute (Coup de Grace) and to Charm
    sprite = "assets/chars/stag.png",
    stats = {
        health = 62, mana = 30, stamina = 60,
        damage = 10, magicDamage = 12,
        defense = 7, magicDefense = 9,
        movement = 4,
        speed = 5,
    },
    startingItems = { "weapon_fangs", "utility_feral_instinct" },
    -- Basic tactics (models/ai.lua): quick and fey, it darts to the kill -- press the foe closest to falling.
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
