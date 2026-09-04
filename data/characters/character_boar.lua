-- Enemy character blueprint. See data/characters/bandit.lua for the shape.
return {
    name = "Wild Boar",
    kind = "beast",
    tier = 2,
    sprite = "assets/chars/boar.png",
    stats = {
        health = 50, mana = 0, stamina = 10,
        damage = 14, magicDamage = 0,
        defense = 7, magicDefense = 1,
        movement = 4,
        speed = 3,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 3, luck = 5,
    },
    -- INNATE MITIGATION (models/character.lua `resist`), in the same unit an armour's resist
    -- table is written in and summed into the same total. This body wears nothing, so this is
    -- what it has instead of a coat -- and the negative line is not an oversight, it is the
    -- price. See docs/bestiary.md, "What a creature wears instead of armour".
    --   Bristle over a hand's depth of fat, which is what a boar is for.
    --   The fat is not structural. A mace does not care what it is wrapped in.
    resist = { slash = 3, impact = -3 },
    startingItems = { "weapon_fangs", "utility_feral_instinct" },
    -- Basic tactics (models/ai.lua): a beast goes for the throat that is already open -- press the foe
    -- closest to falling.
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
