-- Exorcist exemplar (priest subclass). Dedicated body so the discipline reads as itself on the board
-- rather than borrowing Amana's -- companions stay roots-only (docs/disciplines-plan.md, "starred reuse"
-- open call, resolved toward a fresh NPC). Met as a MENTOR/ally: a rite-worker who unmakes what the enemy
-- summons. Home shelf is priest, and she bears no edge (the cleric taboo, docs/classes.md) -- a censer,
-- not a blade. Kit from data/disciplines/exorcist.lua. Signature mechanic: Banish -- remove summons from
-- the field entirely; dispel enemy buffs and hazards. No VN portrait (a template, not a companion) -- it
-- falls back to its composed token.
return {
    name = "Exorcist",
    kind = "humanoid",
    tier = 2,
    sprite = "assets/chars/exorcist.png",
    class = "priest",
    discipline = "exorcist",
    -- Reads the field's foul work before the enemy's throats (models/ai.lua `support`): she unmakes
    -- summons and strips buffs, and heals what is left.
    archetype = "support",
    stats = {
        health = 60, mana = 46, stamina = 12,
        staminaRegen = 2,
        damage = 5, magicDamage = 11,
        defense = 8, magicDefense = 14, -- warded against the magic she is sent to unmake
        movement = 4,
        speed = 3,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 3, luck = 6,
    },
    -- The 3x3 loadout grid (row-major); false = an empty cell. Banish is the build-around -- it removes a
    -- summon outright -- with Dispel to strip a buff or hazard and Silence to shut a caster's mouth; Heal
    -- and a potion heal what the fight leaves.
    startingItems = {
        "weapon_censer",             "ability_banish",           "consumable_healing_potion",
        "ability_dispel_illusions",  "ability_silence",          "utility_cleansing_ward",
        "ability_heal",              "utility_rite_unspoken",                     false,
    },
    defaultAction = "ability_banish",
    -- Basic tactics: heal the moment healing matters; Banish and the dispels carry their own reads about
    -- when a summon or a buff is worth unmaking.
    ai = {
        { priority = "urgent", act = "support", item = "ability_heal", targetPref = "most_wounded",
          when = { subject = "ally_lowest_hp", test = "hp_pct_below", value = 0.65 } },
    },
}
