-- SECOND WATER: Envy's mini sin, and the body that holds the Crucible's first stair.
--
-- IT REPLACES A BUG. Descent.SINS gave this slot to character_homunculus -- the alchemist's SUMMON,
-- "reached only through the Summon Homunculus ability, which scales it by the item's upgrade level".
-- Fielded here as a floor's centrepiece it spawned with 18 health at level 1 and 74 at level 17, which
-- is tier-1 chaff standing where a stratum's boss should be. A blueprint used as both cargo and
-- combatant has to be SPLIT, and this is the split.
--
-- WHAT A MINI SIN IS. A lesser embodiment of the same sin -- not an honour guard with a career of its
-- own -- carrying a cut-down version of its general's rule, which turns up in full at half health:
--
--   from the bell   nothing; a body with a bite
--   at 50%          Lesser Reflection: it copies the WEAKEST foe, once
--   ...and Livia    copies your STRONGEST, at the opening bell, every time
--
-- See data/items/utility/utility_second_wash.lua. `referenceLevel` because the circles are dealt in a
-- fresh order every run, so these numbers are what it is at the depth it was written for and Growth
-- scales them DOWN toward the shallows. `boss = true` keeps it off the execute and Charm tables.
--
-- Health sits around 60% of a general at the same reference level (they run 266-327).
return {
    name = "Second Water",
    kind = "construct",
    tier = 4,
    sprite = "assets/chars/second_water.png",
    referenceLevel = 13,
    boss = true,
    stats = {
        health = 182, mana = 24, stamina = 24,
        staminaRegen = 3,
        damage = 14, magicDamage = 12,
        defense = 9, magicDefense = 12,
        movement = 4,
        speed = 4,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 7, luck = 1,
    },
    -- INNATE MITIGATION (models/character.lua `resist`), in the same unit an armour's resist
    -- table is written in and summed into the same total. This body wears nothing, so this is
    -- what it has instead of a coat -- and the negative line is not an oversight, it is the
    -- price. See docs/bestiary.md, "What a creature wears instead of armour".
    --   The Crucible's first stair, and there is no edge on it that an edge can find.
    --   It is standing in its own overflow, and it is holding a great deal of water.
    resist = { slash = 5, impact = -5, lightning = -5 },
    startingItems = { "weapon_vitreous_bite", "utility_second_wash" },
    defaultAction = "weapon_vitreous_bite",
    -- Basic tactics (models/ai.lua): defensive, because its rule is paid for being WOUNDED. A body that
    -- charged would spend the first half of the fight out of position for the only thing it does.
    archetype = "defensive",
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
