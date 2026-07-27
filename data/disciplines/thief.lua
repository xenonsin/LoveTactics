-- Thief -- rogue subclass.
-- Signature mechanic: Larceny -- strikes steal an item / buff / stat from the target and hand it to
-- you.
-- Exemplar: a guild fence (character_thief, NEW -- pending), met as a RECRUIT.
-- Gate: one quest in the rogue (Undercroft) line -- one_client (slot 4).
-- A subclass opens no earlier than slot 3: a discipline handed over on a line's first or
-- second quest is not earned advancement, it is a welcome gift.
-- See docs/disciplines-plan.md.
return {
    name    = "Thief",
    classes = { "rogue" },
    exemplar = "character_thief", -- NEW, pending
    requiredQuests = { "slot_04_one_client" },
}
