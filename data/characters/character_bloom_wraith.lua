-- A bloom-wraith: the Lust circle's line body, and the one that refuses a clean trade.
--
-- It strikes from cover and gives ground afterwards, so a melee counter finds nothing in reach to answer
-- (data/items/weapon/weapon_bloom_reach.lua). The `glades` carve -- open trails through thick cover -- is
-- what makes that work: there is always somewhere to be that you are not.
--
-- Undead, because the grove has been taking people for a long time and some of them are still up.
return {
    name = "Bloom-Wraith",
    kind = "undead",
    tier = 2,
    sprite = "assets/chars/bloom_wraith.png",
    stats = {
        health = 52, mana = 0, stamina = 22,
        staminaRegen = 3,
        damage = 12, magicDamage = 0,
        defense = 5, magicDefense = 8,
        movement = 5,
        speed = 5,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 3, luck = 0,
    },
    startingItems = { "weapon_bloom_reach" },
    defaultAction = "weapon_bloom_reach",
    -- Basic tactics (models/ai.lua): `skirmish` holds the gap, which is what the hit-and-run is for.
    archetype = "skirmish",
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
