-- Monk -- priest subclass. The charm-driven discipline the priest's foci leave room for.
-- Signature mechanic: Chi -- unarmed strikes build a charge spent on a burst. (The fist charms'
-- unarmedBonus is the first stock.)
-- Exemplar: a fist-and-litany ascetic (character_monk, NEW -- pending), met as a MENTOR.
-- Gate: one quest in the priest (Cathedral) line -- haunted_mill. See docs/disciplines-plan.md.
return {
    name    = "Monk",
    classes = { "priest" },
    exemplar = "character_monk", -- NEW, pending
    requiredQuests = { "haunted_mill" },
}
