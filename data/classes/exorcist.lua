-- Exorcist -- priest subclass.
-- Signature mechanic: Banish -- remove summons from the field entirely; dispel enemy buffs and
-- hazards. (ability_banish / dispel are the first stock.)
-- Exemplar: a dedicated Exorcist (character_exorcist), met as a MENTOR/ally -- a rite-worker who unmakes
-- what the enemy summons. (Amana embodies the same devotion but stays a root companion; the "starred
-- reuse" open call in docs/disciplines-plan.md is resolved toward a fresh body.)
-- Gate: one quest in the priest (Cathedral) line -- rite_of_ashes (slot 3).
-- A subclass opens no earlier than slot 3: a discipline handed over on a line's first or
-- second quest is not earned advancement, it is a welcome gift.
-- See docs/disciplines-plan.md.
return {
    name    = "Exorcist",
    description = "The rite-worker. Banishes summons off the field outright, and strips enemy buffs and hazards.",
    exemplar = "character_exorcist", -- was character_amana (a root companion); dedicated exemplar authored
    requires = { priest = 3 },
}
