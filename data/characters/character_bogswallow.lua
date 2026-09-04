-- A bogswallow: the Gluttony circle's line body, and a grappler rather than a bruiser.
--
-- The swamp's floor is `mire` -- ground that charges a mountain's price and gives back none of a
-- mountain's reach (data/biomes/swamp.lua) -- so crossing is already the expensive thing here. The
-- bogswallow makes it impossible: it Roots on hit, and a Rooted body cannot walk out of a trade with
-- something that grows on trades.
--
-- That is the circle's rule read as position rather than as a heal. Gula's counterplay is "burst her
-- down, deny the long exchange"; this body exists to take the option of leaving away, two floors before
-- anyone has to know why that matters.
--
-- Slow and heavy on purpose. A fast rooter would simply be a lock; this one has to reach you first, and
-- a party that keeps its distance never finds out what it does.
return {
    name = "Bogswallow",
    kind = "beast",
    tier = 2,
    sprite = "assets/chars/bogswallow.png",
    stats = {
        health = 62, mana = 0, stamina = 20,
        staminaRegen = 2,
        damage = 12, magicDamage = 0,
        defense = 8, magicDefense = 3, -- hide and mud; nothing at all against magic
        movement = 3, -- ponderous: it arrives, and then you have a problem
        speed = 3,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 3, luck = 5,
    },
    -- INNATE MITIGATION (models/character.lua `resist`), in the same unit an armour's resist
    -- table is written in and summed into the same total. This body wears nothing, so this is
    -- what it has instead of a coat -- and the negative line is not an oversight, it is the
    -- price. See docs/bestiary.md, "What a creature wears instead of armour".
    --   Waterlogged and boneless through the middle: a blow lands in it and stops there.
    --   It opens like a bag when it is cut, and everything it is soaked in carries a current.
    resist = { impact = 3, slash = -3, lightning = -3 },
    startingItems = { "weapon_swallowing_grip" },
    defaultAction = "weapon_swallowing_grip",
    -- Basic tactics (models/ai.lua): presses whatever is nearest, because what it wants is contact --
    -- picking a target across the board would waste the one thing it does.
    archetype = "aggressive",
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
