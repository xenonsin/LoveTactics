-- THE HUNGRY GHOST, the Crown's ordinary traffic (approved 2026-10-09, "The Crown's Bestiary", slice E). Theme:
-- Hollowness -- the preta, the ghost with a mouth the size of a needle's eye that is never full.
--
-- NEVER FULL (utility_never_full): any heal or draught that lands on a body within 2 is eaten, and the ghost is
-- healed instead. Interred also answers a heal, and the payoff differs: there the heal wounds its patient, here
-- it feeds the thing beside it. How you beat it: heal away from them, pull the wounded back first, or kill the
-- ghosts before the healer works.
--
-- UNDEAD, because it is a dead thing; the meal it steals lands as a drink, so Grave-Cold never turns it.
--
-- It drops the Pinhole Mouth.
return {
    name = "Hungry Ghost",
    race = "undead",
    tier = 2,
    sprite = "assets/chars/hungry_ghost.png",
    archetype = "aggressive",
    stats = {
        health = 36, mana = 0, stamina = 20,
        staminaRegen = 3,
        damage = 0, magicDamage = 9,
        defense = 2, magicDefense = 6,
        movement = 5,
        speed = 5,
        skill = 6, luck = 6,
    },
    -- A shade's line: an edge passes through, a hammer scatters it, and the holy burns it.
    resist = { slash = 2, pierce = 1, impact = -3, holy = -3 },
    startingItems = {
        "weapon_hungry_grasp", "utility_never_full", false,
        false,                 false,                false,
        false,                 false,                false,
    },
    drops = { "utility_pinhole_mouth" },
    defaultAction = "weapon_hungry_grasp",
}
