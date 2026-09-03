-- THE BELOVED: Lust's apex, a 2x2 body, and an apex that makes the DECISION worse rather than the fight.
--
-- Every threshold it is cut past sheds a pair of petal-drifts
-- (data/items/utility/utility_beloveds_devotion.lua). In another circle that would be a screen; here it
-- is a worsening of the dilemma, because every drift on the board is one more argument for holding your
-- good ability -- and holding it is what this stratum charges for.
--
-- So its escalation is not on its stat line and not really on the board either. It is on the player's
-- decision, which is the most Lust thing an apex could do.
--
-- Tier 3's band is 81-154 health.
return {
    name = "The Beloved",
    kind = "demon",
    tier = 3,
    sprite = "assets/chars/the_beloved.png",
    footprint = { w = 2, h = 2 },
    stats = {
        health = 134, mana = 40, stamina = 22,
        staminaRegen = 2,
        damage = 12, magicDamage = 13,
        defense = 10, magicDefense = 14,
        movement = 2,
        speed = 3,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 6, luck = 5,
    },
    startingItems = { "weapon_antler_crown", "utility_beloveds_devotion" },
    defaultAction = "weapon_antler_crown",
    archetype = "defensive",
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
