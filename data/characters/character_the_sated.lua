-- THE SATED: Gluttony's apex, a 2x2 body, and the only fight in the descent that gets easier.
--
-- It opens fed. Everything else on this floor grows on what dies near it; this one has already done all
-- of that and is now mostly inertia. So it is authored as a body at the TOP of its band that shrinks as
-- it is cut -- the phases on its own hide take defense and damage off it at each threshold, and the
-- health it started with was never coming back.
--
-- Which makes it the deliberate inverse of Ira's Unappeased Heart, and the reason it belongs to
-- Gluttony rather than to any other circle: an appetite that has been satisfied is not a threat that
-- escalates, it is one that is running down. The player's read is "this is enormous and it is getting
-- worse at its job", and that is a correct read for once.
--
-- FOOTPRINT 2x2, the second body in the game to use it after the ogre. It blocks all four tiles, is
-- struck from beside any of them, eats an area blast once rather than four times, and slides as one body
-- when knocked back (models/combat.lua). On a mire board that is a door closed across the only dry line.
--
-- Tier 3's band is 81-154 health. It sits at the ceiling, which is the whole conceit.
return {
    name = "The Sated",
    kind = "beast",
    tier = 3,
    sprite = "assets/chars/the_sated.png",
    footprint = { w = 2, h = 2 },
    stats = {
        health = 152, mana = 0, stamina = 24,
        staminaRegen = 2,
        damage = 15, magicDamage = 0,
        defense = 12, magicDefense = 5,
        movement = 2, -- it does not chase. Wherever it is, is where it is
        speed = 2,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 4, luck = 5,
    },
    -- INNATE MITIGATION (models/character.lua `resist`), in the same unit an armour's resist
    -- table is written in and summed into the same total. This body wears nothing, so this is
    -- what it has instead of a coat -- and the negative line is not an oversight, it is the
    -- price. See docs/bestiary.md, "What a creature wears instead of armour".
    --   It opens fed, and everything it ate is between your blow and anything that matters.
    --   So open it. That is the fight -- the meal comes back out and the armour goes with it.
    resist = { impact = 4, slash = -4 },
    startingItems = { "weapon_glutted_bulk", "utility_distended_hide" },
    defaultAction = "weapon_glutted_bulk",
    -- Basic tactics (models/ai.lua): it swings at whatever is in reach, which for a three-wide sweep off
    -- a four-tile body is usually more than one thing.
    archetype = "aggressive",
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
