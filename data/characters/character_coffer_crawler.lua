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
    },
    startingItems = { "weapon_coffer_shell" },
    defaultAction = "weapon_coffer_shell",
    archetype = "aggressive",
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
