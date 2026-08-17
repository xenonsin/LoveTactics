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
    description = "The bodyguard. Redirects the hits aimed at adjacent allies onto your own plate.",
    classes = { "knight" },
    exemplar = "character_sentinel", -- was character_grey_knight (a story-disguised encounter unit); dedicated exemplar authored
    hire = "character_ilse",
    requiredQuests = { "quest_bastion_slot_05" },
}
