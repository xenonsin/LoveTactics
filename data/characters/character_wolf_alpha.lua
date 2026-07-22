-- Enemy character blueprint. A pack leader that joins wolf encounters at higher
-- prestige. See data/characters/bandit.lua for the shape.
return {
    name = "Alpha Wolf",
    sprite = "assets/chars/wolf_alpha.png",
    stats = {
        health = 56, mana = 0, stamina = 20,
        damage = 16, magicDamage = 0,
        defense = 6, magicDefense = 3,
        movement = 5,
        speed = 6, -- fastest in the pack
    },
    startingItems = { "weapon_wolf_fangs", "utility_feral_instinct" },
    -- Basic tactics (models/ai.lua): the alpha calls the pack onto the wounded -- press the foe closest
    -- to falling.
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
