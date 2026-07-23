-- Thief -- rogue subclass.
-- Signature mechanic: Larceny -- strikes steal an item / buff / stat from the target and hand it to
-- you.
-- Exemplar: a guild fence (character_thief, NEW -- pending), met as a RECRUIT.
-- Gate: one quest in the rogue (Undercroft) line -- vault_heist. See docs/disciplines-plan.md.
return {
    name    = "Thief",
    classes = { "rogue" },
    exemplar = "character_thief", -- NEW, pending
    requiredQuests = { "vault_heist" },
}
