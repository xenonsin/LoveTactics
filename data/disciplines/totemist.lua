-- Totemist -- hunter x priest multiclass discipline.
-- Signature mechanic: Ward totems -- plant persistent totems that project holy heal/negate zones
-- around them. Static ground control, the priest's zone nailed to a stake.
-- Exemplar: a ward-carver (character_totemist, NEW -- pending), met as a MENTOR.
-- Gate: earned advancement -- requires a hunter subclass AND a priest subclass unlocked, which opens
-- the_standing_stones (pending). See docs/disciplines-plan.md.
return {
    name    = "Totemist",
    classes = { "hunter", "priest" },
    exemplar = "character_totemist", -- NEW, pending
    requiredQuests = { "the_standing_stones" }, -- pending
}
