-- THE HARTWOOD BRIDE: Lust's mythic, and the body whose call is not a negotiation.
--
-- Stag-headed and antlered, wearing the wood the way somebody wears a name they were given. She Charms
-- everything her sweep catches (data/items/weapon/weapon_antler_crown.lua), so where the Chorister takes
-- one body out of your line, she takes a rank.
--
-- FOOTPRINT 2x2. On the `glades` carve there are open trails between thick cover, and a four-tile body
-- standing in a trail is that trail closed -- which in a circle built on breaking formations means the
-- ground you would have re-formed on is gone.
--
-- Tier 3's band is 81-154 health.
return {
    name = "The Hartwood Bride",
    kind = "demon",
    tier = 3,
    sprite = "assets/chars/the_hartwood_bride.png",
    footprint = { w = 2, h = 2 },
    stats = {
        health = 126, mana = 30, stamina = 24,
        staminaRegen = 3,
        damage = 15, magicDamage = 10,
        defense = 9, magicDefense = 13,
        movement = 4,
        speed = 4,
    },
    startingItems = { "weapon_antler_crown", "utility_chorister_call" },
    defaultAction = "weapon_antler_crown",
    archetype = "aggressive",
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
