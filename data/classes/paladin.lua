-- Paladin -- knight x priest multiclass discipline.
-- Signature mechanic: Ward aura -- a persistent bubble that reduces damage to all adjacent allies.
-- The holy wall.
-- Exemplar: a sworn holy knight (character_paladin, NEW -- pending), met as a MENTOR.
-- Gate: earned advancement -- requires a knight subclass AND a priest subclass unlocked, which opens
-- quest_cathedral_the_oath_at_the_altar (pending). See docs/disciplines-plan.md.
return {
    name    = "Paladin",
    description = "The holy wall. A standing ward aura cuts the damage taken by every ally beside you.",
    exemplar = "character_paladin", -- NEW, pending
    requires = { knight = 7, priest = 7 },
}
