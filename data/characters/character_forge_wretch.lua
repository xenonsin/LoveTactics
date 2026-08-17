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
    },
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
