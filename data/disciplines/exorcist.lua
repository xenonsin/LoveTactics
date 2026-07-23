-- Exorcist -- priest subclass.
-- Signature mechanic: Banish -- remove summons from the field entirely; dispel enemy buffs and
-- hazards. (ability_banish / dispel are the first stock.)
-- Exemplar: Amana (character_amana), met as a MENTOR/ally -- the priest companion learning to banish;
-- her unlock deepens her. (Reuse flagged in docs/disciplines-plan.md.)
-- Gate: one quest in the priest (Cathedral) line -- fallen_confessor. See docs/disciplines-plan.md.
return {
    name    = "Exorcist",
    classes = { "priest" },
    exemplar = "character_amana",
    requiredQuests = { "fallen_confessor" },
}
