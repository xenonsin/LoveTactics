-- A chorister: the Lust circle's specialist, and the body that takes your formation apart.
--
-- It Charms as it acts, on a cooldown (data/traits/trait_lure.lua). Every other circle's control costs
-- you a turn; this one costs you the SHAPE of your company -- and in a forest, a body pulled out of line
-- is a body fighting alone against things it cannot see.
--
-- Kill it or fight the party it has just rearranged. The cooldown is what makes that a real choice
-- rather than a lock: there are turns in which to close the gap it opened.
return {
    name = "Chorister",
    kind = "demon",
    tier = 2,
    sprite = "assets/chars/chorister.png",
    stats = {
        health = 56, mana = 24, stamina = 18,
        staminaRegen = 2,
        damage = 7, magicDamage = 11,
        defense = 5, magicDefense = 10,
        movement = 4,
        speed = 4,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 7, luck = 5,
    },
    -- INNATE MITIGATION (models/character.lua `resist`), in the same unit an armour's resist
    -- table is written in and summed into the same total. This body wears nothing, so this is
    -- what it has instead of a coat -- and the negative line is not an oversight, it is the
    -- price. See docs/bestiary.md, "What a creature wears instead of armour".
    --   Whatever it is wearing closes over a puncture before the puncture finishes.
    --   An edge takes more than it can close, and a censer takes the thing that is doing the closing.
    resist = { pierce = 3, slash = -3, dark = 3, holy = -6 },
    startingItems = { "weapon_petal_touch", "utility_chorister_call" },
    defaultAction = "weapon_petal_touch",
    archetype = "skirmish",
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
