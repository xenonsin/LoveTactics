-- THE GRALLOCH: Gluttony's mini sin, and the body that holds the circle's first stair.
--
-- IT REPLACES A BUG. Descent.SINS gave this slot to character_dire_bear -- a Wild Shape a hunter WEARS,
-- whose pools are placeholders the hunter's own body carries across ("health = 1", tier 0). Fielded
-- alone it spawned with one health at level 1 and 57 at level 17, while hitting for 62. A body used as
-- both cargo and combatant has to be SPLIT, and this is the split: the druid's bear stays hers, and the
-- honour-guard floor gets a body authored to stand on it.
--
-- WHAT A MINI SIN IS. A lesser embodiment of the same sin -- not an honour guard with a career of its
-- own -- carrying a cut-down version of its general's own rule, which turns up in full at half health:
--
--   from the bell   Engorge: it feeds when something DIES near it (data/traits/trait_engorge.lua)
--   at 50%          Ravenous: it feeds on every blow, which is Gula's baseline
--
-- So the circle's first floor teaches the sin the slow way, shows the real thing for the back half of
-- one fight, and then the stair goes down to Gula, who has had it since her opening bell. The general
-- becomes a recognition rather than a surprise -- which is what two floors per circle is FOR. See
-- data/items/utility/utility_gralloch_hook.lua for the phase table.
--
-- `referenceLevel` because the circles are dealt in a fresh order every run: these numbers are what it
-- is at the depth it was written for, and Growth.spawn scales them DOWN toward the shallows rather than
-- growing them up from a base. `boss = true` keeps it off the execute and Charm tables, as every
-- centrepiece is.
--
-- Health sits around 60% of a general at the same reference level (they run 266-327), so the tier reads
-- as a real step up from the line and a real step below the sin.
return {
    name = "The Gralloch",
    kind = "beast",
    tier = 4,
    sprite = "assets/chars/the_gralloch.png",
    referenceLevel = 13,
    boss = true,
    stats = {
        health = 178, mana = 0, stamina = 28,
        staminaRegen = 3,
        damage = 17, magicDamage = 0,
        defense = 11, magicDefense = 6, -- hide and fat; it never learned anything about magic either
        movement = 4,
        speed = 4,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 5, luck = 6,
    },
    -- INNATE MITIGATION (models/character.lua `resist`), in the same unit an armour's resist
    -- table is written in and summed into the same total. This body wears nothing, so this is
    -- what it has instead of a coat -- and the negative line is not an oversight, it is the
    -- price. See docs/bestiary.md, "What a creature wears instead of armour".
    --   Fat over fat over fat. A blow sinks in and the circle absorbs it.
    --   A gralloch is what you do to a carcass. The word is a verb, and it is done with a knife.
    resist = { impact = 5, slash = -5 },
    startingItems = { "weapon_tallow_maw", "utility_gralloch_hook" },
    defaultAction = "weapon_tallow_maw",
    -- Basic tactics (models/ai.lua): it finishes what is closest to falling, which is the same instinct
    -- both halves of its rule are paid for -- the kill before the phase, the blow after it.
    archetype = "aggressive",
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
