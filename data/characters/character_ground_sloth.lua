-- GROUND SLOTH: the circle's namesake, from the Ice Age, on the tundra's approach ("Sloth's Bestiary", slice A,
-- 2026-10-04).
--
--   BANKED   each turn no foe is in its reach, it does nothing at all and banks the turn, up to 3, shown on the
--            badge (status_banked). When a foe comes into reach, its next turn swings once per banked turn and
--            once more for the turn itself. Any blow that lands on it knocks one turn out of the bank. It moves 1.
--            (utility_banked_turns, trait_banked_turns, weapon_ground_sloth_claws; models/sloth_beasts.lua)
--
-- THE COUNTERPLAY, STATED, and it is the review's own: don't walk into it with a full bank. Chip it from range to
-- empty the bank first, or send your guard in to take the flurry.
--
-- Shaggy over a hide like a bark: a blade catches in the fur, a club finds the body under it.
return {
    name = "Ground Sloth",
    race = "beast",
    tier = 2,
    sprite = "assets/chars/ground_sloth.png",
    stats = {
        health = 64, mana = 0, stamina = 26,
        staminaRegen = 3,
        damage = 10, magicDamage = 0,
        defense = 6, magicDefense = 3,
        movement = 1, -- "It moves 1."
        speed = 3,
        skill = 4, luck = 2,
    },
    resist = { slash = 2, impact = -2 },
    startingItems = {
        "weapon_ground_sloth_claws", "utility_banked_turns", false,
        false,                       false,                  false,
        false,                       false,                  false,
    },
    drops = { "utility_sleepers_claws" },
    defaultAction = "weapon_ground_sloth_claws",
    archetype = "aggressive",
}
