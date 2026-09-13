-- Totemist -- hunter x priest multiclass discipline.
-- Signature mechanic: Ward totems -- plant persistent totems that project holy heal/negate zones
-- around them. Static ground control, the priest's zone nailed to a stake.
-- Exemplar: a ward-carver (character_totemist, NEW -- pending), met as a MENTOR.
-- Gate: earned advancement -- requires a hunter subclass AND a priest subclass unlocked, which opens
-- quest_hunters_lodge_the_standing_stones (pending). See docs/disciplines-plan.md.
return {
    name    = "Totemist",
    description = "Plants totems that work on their own. Each stake projects a field around it that heals "
        .. "the party or negates what is cast into it.",
    exemplar = "character_totemist", -- NEW, pending
    requires = { hunter = 8, priest = 8 },
}
