-- Enemy character blueprint. See data/characters/bandit.lua for the shape.
return {
    name = "Wolf",
    sprite = "assets/chars/wolf.png",
    stats = {
        health = 28, mana = 0, stamina = 18,
        damage = 10, magicDamage = 0,
        defense = 3, magicDefense = 2,
        movement = 5, -- fast, low health
        speed = 5,
    },
    startingItems = { "weapon_wolf_fangs", "utility_feral_instinct" },
    -- Basic tactics (models/ai.lua): a pack pulls down the wounded first -- press the foe closest to falling.
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
