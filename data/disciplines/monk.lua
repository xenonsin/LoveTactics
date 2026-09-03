-- Monk -- priest subclass. The charm-driven discipline the priest's foci leave room for.
-- Signature mechanic: Chi -- unarmed strikes build a charge spent on a burst. (The fist charms'
-- unarmedBonus is the first stock.)
-- Exemplar: a fist-and-litany ascetic (character_monk, NEW -- pending), met as a MENTOR.
-- Gate: one quest in the priest (Cathedral) line -- purge_in_the_fold (slot 4).
-- A subclass opens no earlier than slot 3: a discipline handed over on a line's first or
-- second quest is not earned advancement, it is a welcome gift.
-- See docs/disciplines-plan.md.
return {
    name    = "Monk",
    description = "The ascetic. Unarmed strikes bank chi, and the bank is spent whole on a single burst.",
    classes = { "priest" },
    exemplar = "character_monk", -- NEW, pending
    requiredLevel = { priest = 4 },
}
