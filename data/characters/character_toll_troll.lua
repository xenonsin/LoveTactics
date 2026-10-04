-- THE TOLL-TROLL, rung 3 (approved 2026-10-04, "Sloth's Bestiary", slice B): the troll under the bridge.
--
-- THE TOLL (utility_the_toll): any of your bodies that USES something -- an attack, an ability, an item -- within
-- its reach pays first: the troll strikes it before the action resolves. A body that only walks through, or waits,
-- is left alone. Its reach is the Bridge Maul's, two tiles.
--
-- IT HOLDS ITS BRIDGE (`movement = 0`, the sentry's opt-out in tests/bestiary_spec.lua). The review's counter is
-- "act from outside its reach, or let one body stand in reach and do nothing while the others burn it", and both
-- halves need a troll that stays where it stands: a toll that walked after you would be a reach you could never
-- step out of. It still swings at whatever stands within two on its own turn.
--
-- An elite's three pieces: the maul, the toll and a leather coat. It drops Bridge Tax (Mammonite).
return {
    name = "Toll-Troll",
    race = "troll",
    tier = 3,
    class = "fighter",
    sprite = "assets/chars/toll_troll.png",
    archetype = "aggressive",
    stats = {
        health = 120, mana = 0, stamina = 30,
        staminaRegen = 4,
        damage = 13, magicDamage = 0,
        defense = 6, magicDefense = 3,
        movement = 0, -- it does not leave the bridge
        speed = 3,
        skill = 5, luck = 3,
    },
    startingItems = {
        "weapon_bridge_maul", "utility_the_toll", "armor_leather_armor",
        false,                false,              false,
        false,                false,              false,
    },
    drops = { "utility_bridge_tax" },
    defaultAction = "weapon_bridge_maul",
    signatureWeapon = "weapon_bridge_maul",
}
