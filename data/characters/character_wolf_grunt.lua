-- Enemy character blueprint. See data/characters/bandit.lua for the shape.
return {
    name = "Wolf",
    kind = "beast",
    tier = 1,
    sprite = "assets/chars/wolf.png",
    stats = {
        health = 28, mana = 0, stamina = 18,
        damage = 13, magicDamage = 0,
        defense = 3, magicDefense = 2,
        movement = 5, -- fast, low health
        speed = 5,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 2, luck = 5,
    },
    -- INNATE MITIGATION (models/character.lua `resist`), in the same unit an armour's resist
    -- table is written in and summed into the same total. This body wears nothing, so this is
    -- what it has instead of a coat -- and the negative line is not an oversight, it is the
    -- price. See docs/bestiary.md, "What a creature wears instead of armour".
    --   Winter coat over loose hide -- a blade drags through hair and takes the skin, not the wolf.
    --   Hide does nothing about weight. A mace arrives at the bone whatever is in front of it.
    resist = { slash = 2, impact = -2 },
    startingItems = { "weapon_wolf_fangs", "utility_feral_instinct" },
    -- WHAT IT IS KNOWN FOR (docs/drops.md). Neither entry is a body part -- that rule is absolute and
    -- the fangs and the instinct are on the far side of it, unstealable and on no shelf. These are the
    -- two things a wolf actually leaves: its coat, and the wind it never seems to run out of.
    --
    -- The hide is the piece that teaches a rule by breaking one -- it is the only hide in the game that
    -- costs its wearer no movement -- which is worth meeting on the commonest animal on the road rather
    -- than somewhere deep.
    drops = { "utility_endurance", "armor_runners_hide" },
    -- Basic tactics (models/ai.lua): a pack pulls down the wounded first -- press the foe closest to falling.
    -- Which the teeth now do something about: weapon_wolf_fangs bites heavier and opens a wound against
    -- prey at or below half health, so this rule and the weapon finally say the same thing.
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
