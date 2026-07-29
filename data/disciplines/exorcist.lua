-- Exorcist -- priest subclass.
-- Signature mechanic: Banish -- remove summons from the field entirely; dispel enemy buffs and
-- hazards. (ability_banish / dispel are the first stock.)
-- Exemplar: Amana (character_amana), met as a MENTOR/ally -- the priest companion learning to banish;
-- her unlock deepens her. (Reuse flagged in docs/disciplines-plan.md.)
-- Gate: one quest in the priest (Cathedral) line -- rite_of_ashes (slot 3).
-- A subclass opens no earlier than slot 3: a discipline handed over on a line's first or
-- second quest is not earned advancement, it is a welcome gift.
-- See docs/disciplines-plan.md.
return {
    name    = "Exorcist",
    classes = { "priest" },
    exemplar = "character_amana",
    requiredQuests = { "quest_cathedral_slot_03" },
}
