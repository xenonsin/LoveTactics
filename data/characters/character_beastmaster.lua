-- Beastmaster exemplar (hunter subclass). Dedicated body so the discipline reads as itself on the board
-- rather than borrowing Kaya's -- companions stay roots-only (docs/disciplines-plan.md, "starred reuse"
-- open call, resolved toward a fresh NPC). Met as a RECRUIT: a houndmaster who calls the pack. Home shelf
-- is hunter. Kit from data/disciplines/beastmaster.lua. Signature mechanic: Bond -- a persistent summoned
-- beast that acts each turn under command. No VN portrait (a template, not a companion) -- it falls back
-- to its composed token.
return {
    name = "Beastmaster",
    sprite = "assets/chars/beastmaster.png",
    class = "hunter",
    -- Fields the wolf, keeps the distance a kiter needs, and lets the Bond do the closing (models/ai.lua
    -- `skirmish`).
    archetype = "skirmish",
    stats = {
        health = 64, mana = 22, stamina = 15,
        staminaRegen = 2,
        damage = 15, magicDamage = 2,
        defense = 8, magicDefense = 8,
        movement = 4,
        speed = 5,
    },
    -- The 3x3 loadout grid (row-major); false = an empty cell. Summon Wolf fields the Bond and the
    -- Beastlord's Bond keeps it standing; the horn and whistle carry the pack-command, a longbow keeps
    -- the master back where a handler belongs.
    startingItems = {
        "weapon_iron_longbow", "ability_summon_wolf",     "consumable_healing_potion",
        "utility_beastlords_bond", "utility_companion_whistle", "utility_hunting_horn",
        "armor_stalkers_pelt", false,                     false,
    },
    defaultAction = "weapon_iron_longbow",
    -- Basic tactics: loose the bow at whatever is in reach; the Bond beast and the horns carry the rest.
    ai = {
        { priority = "high", act = "attack", item = "weapon_iron_longbow",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
