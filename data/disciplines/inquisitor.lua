-- Inquisitor -- rogue x priest multiclass discipline.
-- Signature mechanic: Judgment -- mark a target as heretic; your execute then deals holy damage and
-- dispels their buffs. Stealth plus smite.
-- Exemplar: a witch-finder (character_inquisitor, NEW -- pending), met as a BOSS.
-- Gate: earned advancement -- requires a rogue subclass AND a priest subclass unlocked, which opens
-- the_confession (pending). See docs/disciplines-plan.md.
return {
    name    = "Inquisitor",
    classes = { "rogue", "priest" },
    exemplar = "character_inquisitor", -- NEW, pending
    requiredQuests = { "the_confession" }, -- pending
}
