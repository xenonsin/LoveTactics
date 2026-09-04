-- A forge-wretch: the Wrath circle's specialist, and the body that carries Kindling.
--
-- It sharpens with every blow it takes, up to a ceiling (data/traits/trait_kindling.lua). So chipping it
-- is strictly worse than committing: a party that pokes it four times has built the thing that is about
-- to hit them, and a party that drops it in two turns never finds out what it does.
--
-- The ceiling is what makes the lesson learnable. Ira's version has no ceiling and a second compounding
-- term on top (data/traits/trait_wrath_rising.lua); this one goes up visibly and then stops, so a player
-- can watch the number, understand the rule, and carry it down the stair.
return {
    name = "Forge-Wretch",
    kind = "demon",
    tier = 2,
    sprite = "assets/chars/forge_wretch.png",
    stats = {
        health = 64, mana = 0, stamina = 22,
        staminaRegen = 2,
        damage = 11, magicDamage = 0, -- it starts soft; that is the whole shape of it
        defense = 7, magicDefense = 6,
        movement = 4,
        speed = 3,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 6, luck = 5,
    },
    -- INNATE MITIGATION (models/character.lua `resist`), in the same unit an armour's resist
    -- table is written in and summed into the same total. This body wears nothing, so this is
    -- what it has instead of a coat -- and the negative line is not an oversight, it is the
    -- price. See docs/bestiary.md, "What a creature wears instead of armour".
    --   It sharpens on being struck, and the part of it that does the sharpening is slag.
    --   Slag is porous. There is a way through it, and a point is the shape of that way.
    resist = { impact = 3, pierce = -3, fire = 3, holy = -6 },
    startingItems = { "weapon_cinder_brand", "utility_forge_scar" },
    defaultAction = "weapon_cinder_brand",
    -- Basic tactics (models/ai.lua): it walks in and stays in. A body paid for taking blows should be
    -- standing where blows are.
    archetype = "aggressive",
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
