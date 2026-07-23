-- Bulwark -- knight subclass.
-- Signature mechanic: Shove-lock -- knockback that also Halts the displaced. The immovable wall that
-- moves everyone else.
-- Exemplar: the Road-Captain (character_greywatch_captain), met as a MENTOR/ally -- a guard who holds
-- a line.
-- Gate: one quest in the knight (Bastion) line -- held_position. See docs/disciplines-plan.md.
return {
    name    = "Bulwark",
    classes = { "knight" },
    exemplar = "character_greywatch_captain",
    requiredQuests = { "held_position" },
}
