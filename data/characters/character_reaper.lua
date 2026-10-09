-- REAPER: the Crown's dead thing ("The Crown's Bestiary", slice C, approved 2026-10-09).
--
--   THE HARVEST   a scythe sweep of every tile around it. Any body in the sweep under a quarter health is Downed at
--                 once. A line on every health bar shows the threshold (weapon_reapers_scythe, trait_the_line)
--
-- THE COUNTERPLAY, STATED, and it is the review's own: heal the wounded above the line, or pull them out of its ring.
-- Root or Stun it before it reaches a weak body.
--
-- UNDEAD, and a dead thing as the review asked: not a demon, so its scythe carries no fire and holy is answered by
-- the body's own line below rather than a race's. Grave-Cold (utility_grave_cold, the barrow dead's) turns a heal aimed
-- at it into a wound, so the priest who keeps the company above the line cannot keep it standing too.
--
-- Its fight is Seek Death: the locusts hold bodies at 1, which is under every line there is.
return {
    name = "Reaper",
    race = "undead",
    tier = 3,
    sprite = "assets/chars/reaper.png",
    stats = {
        health = 112, mana = 0, stamina = 32,
        staminaRegen = 4,
        damage = 12, magicDamage = 0,
        defense = 5, magicDefense = 6,
        movement = 4, -- it walks; nothing it has come for has ever outrun it
        speed = 4,
        skill = 7, luck = 4,
    },
    -- A robe over nothing: a point finds no body behind the cloth, and a club finds the bones. The holy line is the
    -- dead's.
    resist = { pierce = 2, impact = -2, holy = -3 },
    startingItems = {
        "weapon_reapers_scythe", "utility_the_line", "utility_grave_cold",
        false,                   false,              false,
        false,                   false,              false,
    },
    drops = { "ability_the_harvest" },
    defaultAction = "weapon_reapers_scythe",
    archetype = "aggressive",
}
