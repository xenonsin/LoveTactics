-- Sentinel -- knight subclass.
-- Signature mechanic: Intercept -- redirect adjacent allies' incoming hits onto yourself (the
-- oathward/martyr guard redirect, read as a bodyguard bubble).
-- Exemplar: the Knight in Grey (character_grey_knight), met as a MENTOR -- a guard by archetype.
-- Gate: one quest in the knight (Bastion) line -- greywatch (slot 5).
-- A subclass opens no earlier than slot 3: a discipline handed over on a line's first or
-- second quest is not earned advancement, it is a welcome gift.
-- See docs/disciplines-plan.md.
return {
    name    = "Sentinel",
    classes = { "knight" },
    exemplar = "character_sentinel", -- was character_grey_knight (a story-disguised encounter unit); dedicated exemplar authored
    requiredQuests = { "slot_05_greywatch" },
}
