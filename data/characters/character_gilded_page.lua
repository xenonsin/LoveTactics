-- A gilded page: the Pride circle's swarm, and worth nothing whatsoever alone.
--
-- That is the lesson, stated at the cheapest rung. Both halves of the rank rule read adjacency LIVE
-- (data/items/utility/utility_rank_and_file.lua), so a page standing with five others is armoured and
-- hitting properly, and the same page pulled into a doorway is a suit of armour with opinions.
--
-- Tier 1's band is 1-30 health (Balance.HEALTH_BANDS).
return {
    name = "Gilded Page",
    kind = "construct",
    tier = 1,
    sprite = "assets/chars/gilded_page.png",
    stats = {
        health = 22, mana = 0, stamina = 14,
        staminaRegen = 2,
        damage = 4, magicDamage = 0, -- almost nothing, until it is standing next to three of itself
        defense = 3, magicDefense = 2,
        movement = 4,
        speed = 4,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 4, luck = 0,
    },
    startingItems = { "weapon_gilded_pike", "utility_rank_and_file" },
    defaultAction = "weapon_gilded_pike",
    -- Basic tactics (models/ai.lua): `defensive` keeps it from breaking its own rank to chase, which is
    -- the one thing that would make the formation stop being a formation.
    archetype = "defensive",
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
