-- Paladin -- knight x priest multiclass discipline.
-- Signature mechanic: Ward aura -- a persistent bubble that reduces damage to all adjacent allies.
-- The holy wall.
-- Exemplar: a sworn holy knight (character_paladin, NEW -- pending), met as a MENTOR.
-- Gate: earned advancement -- requires a knight subclass AND a priest subclass unlocked, which opens
-- quest_cathedral_the_oath_at_the_altar (pending). See docs/disciplines-plan.md.
return {
    name    = "Paladin",
    description = "Stands as a ward for the party. A standing aura cuts the damage every ally beside you "
        .. "takes, and banners hold that ground while they stand.",
    exemplar = "character_paladin", -- NEW, pending
    requires = { knight = 7, priest = 7 },
}
