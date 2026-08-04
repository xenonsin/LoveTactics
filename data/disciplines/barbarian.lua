-- Barbarian -- fighter subclass. A sharper reading of wrath's own shelf.
-- Signature mechanic: Rage -- damage rises as your own HP falls; some strikes cost HP to land harder.
-- Exemplar: an arena berserker (character_barbarian, NEW -- pending), met as a BOSS.
-- Gate: one quest in the fighter (Colosseum) line -- blood_in_the_sand. See docs/disciplines-plan.md.
return {
    name    = "Barbarian",
    description = "Wrath read straight. Damage climbs as your own health falls, and the heaviest strikes are paid for in blood.",
    classes = { "fighter" },
    exemplar = "character_barbarian", -- NEW, pending
    requiredQuests = { "quest_colosseum_slot_06" },
}
