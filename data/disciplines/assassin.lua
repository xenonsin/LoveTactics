-- Assassin -- rogue subclass.
-- Signature mechanic: Blink-execute -- teleport to a wounded target, guaranteed finish, return to
-- origin.
-- Exemplar: a killer sent for you (character_assassin, NEW -- pending), met as a BOSS.
-- Gate: one quest in the rogue (Undercroft) line -- accounts_settled. See docs/disciplines-plan.md.
return {
    name    = "Assassin",
    description = "The killer sent for one name. Blink to a wounded target, land a guaranteed finish, and return to the tile you left.",
    classes = { "rogue" },
    exemplar = "character_assassin", -- NEW, pending
    hire = "character_vess",
    requiredQuests = { "quest_undercroft_slot_05" },
}
