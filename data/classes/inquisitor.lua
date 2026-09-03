-- Inquisitor -- rogue x priest multiclass discipline.
-- Signature mechanic: Judgment -- mark a target as heretic; your execute then deals holy damage and
-- dispels their buffs. Stealth plus smite.
-- Exemplar: a witch-finder (character_inquisitor, NEW -- pending), met as a BOSS.
-- Gate: earned advancement -- requires a rogue subclass AND a priest subclass unlocked, which opens
-- quest_cathedral_the_confession (pending). See docs/disciplines-plan.md.
return {
    name    = "Inquisitor",
    description = "Stealth plus smite. Mark a heretic, and the execute that follows lands as holy damage and strips their blessings.",
    exemplar = "character_inquisitor", -- NEW, pending
    requires = { rogue = 6, priest = 6 },
}
