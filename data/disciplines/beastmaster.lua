-- Beastmaster -- hunter subclass.
-- Signature mechanic: Bond -- a persistent summoned beast that acts each turn under your command.
-- Exemplar: Kaya (character_kaya), met as a RECRUIT -- the hunter companion learning to call the
-- pack; her unlock is a companion quest. (Reuse flagged in docs/disciplines-plan.md.)
-- Gate: one quest in the hunter (Lodge) line -- sacred_stag. See docs/disciplines-plan.md.
return {
    name    = "Beastmaster",
    classes = { "hunter" },
    exemplar = "character_kaya",
    requiredQuests = { "sacred_stag" },
}
