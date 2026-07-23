-- Sentinel -- knight subclass.
-- Signature mechanic: Intercept -- redirect adjacent allies' incoming hits onto yourself (the
-- oathward/martyr guard redirect, read as a bodyguard bubble).
-- Exemplar: the Knight in Grey (character_grey_knight), met as a MENTOR -- a guard by archetype.
-- Gate: one quest in the knight (Bastion) line -- relief_column. See docs/disciplines-plan.md.
return {
    name    = "Sentinel",
    classes = { "knight" },
    exemplar = "character_grey_knight",
    requiredQuests = { "relief_column" },
}
