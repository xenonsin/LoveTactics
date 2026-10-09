-- ERINYS: the Crown's flying archer ("The Crown's Bestiary", slice B, approved 2026-10-09). One of the Furies, who
-- punish a crime with its own answer.
--
--   FIT THE CRIME   her arrow lands the status that answers what the target did on its last turn. Attacked:
--                   Disarmed. Cast: Silenced. Moved: Root. Healed someone: Interred (weapon_fit_the_crime;
--                   models/crown_demons.lua). Her intent shows who she is aiming at.
--
-- THE COUNTERPLAY, STATED, and it is the review's own: the body she aims at chooses its crime -- act in the way
-- whose punishment you can afford, or step behind cover. She flies on the shared Wings (utility_manticore_wings),
-- so the ground does nothing for her and nothing for her cover. A demon, so her arrows burn and she takes holy
-- the harder.
return {
    name = "Erinys",
    race = "demon",
    tier = 3,
    sprite = "assets/chars/erinys.png",
    stats = {
        health = 90, mana = 0, stamina = 26,
        staminaRegen = 4,
        damage = 13, magicDamage = 0,
        defense = 5, magicDefense = 7,
        movement = 5,
        speed = 6,
        skill = 8, luck = 6,
    },
    -- Feathers lie flat and turn an edge; a point goes between them, which is how a flier is brought down.
    resist = { slash = 3, pierce = -3, fire = 3 },
    startingItems = {
        "weapon_fit_the_crime", "utility_manticore_wings", false,
        false,                  false,                     false,
        false,                  false,                     false,
    },
    drops = { "ability_furys_verdict" },
    defaultAction = "weapon_fit_the_crime",
    archetype = "skirmish",
}
