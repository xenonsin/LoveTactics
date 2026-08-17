-- Bulwark -- knight subclass.
-- Signature mechanic: Shove-lock -- knockback that also Halts the displaced. The immovable wall that
-- moves everyone else.
-- Exemplar: the Road-Captain (character_greywatch_captain), met as a MENTOR/ally -- a guard who holds
-- a line.
-- Gate: one quest in the knight (Bastion) line -- held_position. See docs/disciplines-plan.md.
return {
    name    = "Bulwark",
    description = "The immovable wall that moves everyone else. Knockback that also Halts whoever it displaced.",
    classes = { "knight" },
    exemplar = "character_bulwark", -- was character_greywatch_captain (a story-disguised encounter unit); dedicated exemplar authored
    hire = "character_dov",
    requiredQuests = { "quest_bastion_slot_03" },
}
