-- THE PATCHWORK: one of Envy's one-off families, on the Ribstone Waste's approach ("Envy's Bestiary", round 1). A
-- body sewn together from people who each wanted to be somebody else, and it suffers for all of them.
--
--   STITCHED TO YOU   whoever last struck it is Conjoined to it -- the existing status -- so that body takes half of
--                     every wound the Patchwork takes. The stitch moves to each new attacker
--                     (trait_stitched_to_you; models/envy_oneoffs.lua)
--
-- THE COUNTERPLAY, STATED, and it is the review's own: spread the work across several bodies so no one carries the
-- stitch for long, or end it with damage over time from a distance.
--
-- Conjoined is the mage's binding, and it is a binding both ways: the stitched body's own wounds reach the
-- Patchwork at half too. Undead; stitches part under an edge and hold against a club.
return {
    name = "The Patchwork",
    race = "undead",
    tier = 3,
    sprite = "assets/chars/patchwork.png",
    stats = {
        health = 110, mana = 0, stamina = 24,
        staminaRegen = 3,
        damage = 13, magicDamage = 0,
        defense = 6, magicDefense = 3,
        movement = 4,
        speed = 3,
        skill = 4, luck = 2,
    },
    resist = { impact = 3, slash = -3, holy = -3 },
    startingItems = {
        "weapon_sutured_arm", "utility_stitched_to_you", false,
        false,                false,                     false,
        false,                false,                     false,
    },
    drops = { "ability_surgeons_thread" },
    defaultAction = "weapon_sutured_arm",
    archetype = "aggressive",
}
