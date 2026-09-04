-- A hollow sleeper: the Sloth circle's specialist, and the body that carries Torpor.
--
-- It swears two of your company together when it acts (data/traits/trait_torpor.lua), so from that turn
-- on those two bodies either move as a pair or are bitten for not. Acedia does this to EVERYONE at the
-- opening bell; the sleeper does it to two, in the middle of the fight, where you can watch it happen
-- and work out what it means.
--
-- Undead rather than elemental, and that is the tell: this is not the weather, it is somebody who
-- stopped.
return {
    name = "Hollow Sleeper",
    kind = "undead",
    tier = 2,
    sprite = "assets/chars/hollow_sleeper.png",
    stats = {
        health = 68, mana = 16, stamina = 18,
        staminaRegen = 2,
        damage = 9, magicDamage = 10,
        defense = 6, magicDefense = 10,
        movement = 3,
        speed = 3,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 2, luck = 0,
    },
    -- INNATE MITIGATION (models/character.lua `resist`), in the same unit an armour's resist
    -- table is written in and summed into the same total. This body wears nothing, so this is
    -- what it has instead of a coat -- and the negative line is not an oversight, it is the
    -- price. See docs/bestiary.md, "What a creature wears instead of armour".
    --   Hollow, and hollow answers both of the questions steel usually asks.
    --   It answers none of the questions weight asks. Nothing in there holds a shape under a hammer.
    resist = { pierce = 3, slash = 3, impact = -6, holy = -6 },
    startingItems = { "weapon_drift_touch", "utility_sleepers_weight" },
    defaultAction = "weapon_drift_touch",
    archetype = "aggressive",
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
