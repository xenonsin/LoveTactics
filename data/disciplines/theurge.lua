-- Theurge -- mage x priest multiclass discipline.
-- Signature mechanic: Channelled miracle -- wind-up holy spells that scale with the number of
-- channel turns held; divine hazards laid on the ground.
-- Exemplar: a channelling divine (character_theurge, NEW -- pending), met as a MENTOR.
-- Gate: earned advancement -- requires a mage subclass AND a priest subclass unlocked, which opens
-- the_twin_liturgy (pending). See docs/disciplines-plan.md.
return {
    name    = "Theurge",
    classes = { "mage", "priest" },
    exemplar = "character_theurge", -- NEW, pending
    requiredQuests = { "the_twin_liturgy" }, -- pending
}
