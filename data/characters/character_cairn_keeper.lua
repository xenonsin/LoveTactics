-- CAIRN-KEEPER: the Bog-Bound's keeper of the oldest grave, on Sloth's approach ("Sloth's Bestiary", 2026-10-04,
-- slice C). It holds a grave at the back of the line.
--
--   DEEPER PEAT      within 3 of it, the line's rule is doubled: a threshold of 16, and a 4-movement toll
--                    (utility_deeper_peat; models/sloth_bog.lua). It stands inside its own reach.
--   BOG-BOUND        and it is one of them: Past Feeling and the Mire Holds (utility_bog_bound)
--
-- THE COUNTER, STATED: kill or break the Cairn-Keeper first. Sundered, its peat goes shallow; dead, the line is
-- back to 8. It throws its cold from range (Grave-Cold) and keeps its distance, so reaching it is the fight.
--
-- Undead, so it takes holy the harder. Its wrappings are older and drier than a Bog Body's: an edge parts them.
return {
    name = "Cairn-Keeper",
    race = "undead",
    tier = 2,
    sprite = "assets/chars/cairn_keeper.png",
    stats = {
        health = 48, mana = 0, stamina = 20,
        staminaRegen = 3,
        damage = 0, magicDamage = 10,
        defense = 4, magicDefense = 6,
        movement = 3,
        speed = 3,
        skill = 4, luck = 3,
    },
    resist = { slash = -2, impact = 2, holy = -3 },
    startingItems = {
        "weapon_grave_cold", "utility_bog_bound", "utility_deeper_peat",
        false,               false,               false,
        false,               false,               false,
    },
    drops = { "utility_cairn_stone" },
    defaultAction = "weapon_grave_cold",
    archetype = "skirmish",
}
