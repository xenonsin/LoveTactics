-- A coffer-crawler: the Greed circle's line body, and the one thing on the floor worth killing.
--
-- It is armoured in what it has swallowed -- slow, heavy, and standing between you and whatever you
-- actually wanted. Everything else in this circle TAKES from you; the crawler is the one that gives it
-- back, if you can afford the turns to open it.
--
-- Which is the decision the stratum keeps asking in different words: is this worth the tempo.
return {
    name = "Coffer-Crawler",
    kind = "construct",
    tier = 2,
    sprite = "assets/chars/coffer_crawler.png",
    stats = {
        health = 72, mana = 0, stamina = 18,
        staminaRegen = 2,
        damage = 10, magicDamage = 0,
        defense = 11, magicDefense = 4, -- coin is excellent armour and no help at all against a spell
        movement = 2,
        speed = 2,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 6, luck = 0,
    },
    -- INNATE MITIGATION (models/character.lua `resist`), in the same unit an armour's resist
    -- table is written in and summed into the same total. This body wears nothing, so this is
    -- what it has instead of a coat -- and the negative line is not an oversight, it is the
    -- price. See docs/bestiary.md, "What a creature wears instead of armour".
    --   Armoured in what it swallowed -- coin, plate, somebody's greaves -- and none of it is cuttable.
    --   None of it is FIXED either. It is a bag of loose metal, and a hammer makes it ring.
    resist = { slash = 3, pierce = 3, impact = -6 },
    startingItems = { "weapon_coffer_shell" },
    defaultAction = "weapon_coffer_shell",
    archetype = "aggressive",
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
