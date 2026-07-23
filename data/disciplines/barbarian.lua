-- Barbarian -- fighter subclass. A sharper reading of wrath's own shelf.
-- Signature mechanic: Rage -- damage rises as your own HP falls; some strikes cost HP to land harder.
-- Exemplar: an arena berserker (character_barbarian, NEW -- pending), met as a BOSS.
-- Gate: one quest in the fighter (Colosseum) line -- blood_in_the_sand. See docs/disciplines-plan.md.
return {
    name    = "Barbarian",
    classes = { "fighter" },
    exemplar = "character_barbarian", -- NEW, pending
    requiredQuests = { "blood_in_the_sand" },
}
