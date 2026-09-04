-- Enemy character blueprint. A pack leader that joins wolf encounters at higher
-- prestige. See data/characters/bandit.lua for the shape.
return {
    name = "Alpha Wolf",
    kind = "beast",
    tier = 2,
    sprite = "assets/chars/wolf_alpha.png",
    stats = {
        health = 56, mana = 0, stamina = 20,
        damage = 16, magicDamage = 0,
        defense = 6, magicDefense = 3,
        movement = 5,
        speed = 6, -- fastest in the pack
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 3, luck = 5,
    },
    -- INNATE MITIGATION (models/character.lua `resist`), in the same unit an armour's resist
    -- table is written in and summed into the same total. This body wears nothing, so this is
    -- what it has instead of a coat -- and the negative line is not an oversight, it is the
    -- price. See docs/bestiary.md, "What a creature wears instead of armour".
    --   The same coat the pack wears, on the body that has kept it longest.
    --   And the same answer: weight goes through hide without asking.
    resist = { slash = 3, impact = -3 },
    startingItems = { "weapon_wolf_fangs", "utility_feral_instinct" },
    -- Basic tactics (models/ai.lua): the alpha calls the pack onto the wounded -- press the foe closest
    -- to falling.
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
