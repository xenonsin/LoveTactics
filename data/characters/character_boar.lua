-- Enemy character blueprint. See data/characters/bandit.lua for the shape.
return {
    name = "Wild Boar",
    sprite = "assets/chars/boar.png",
    stats = {
        health = 50, mana = 0, stamina = 40,
        damage = 14, magicDamage = 0,
        defense = 8, magicDefense = 1,
        movement = 3,
        speed = 3,
    },
    startingItems = { "weapon_fangs", "utility_feral_instinct" },
    -- Basic tactics (models/ai.lua): a beast goes for the throat that is already open -- press the foe
    -- closest to falling.
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
