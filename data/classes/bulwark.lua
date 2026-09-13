-- Bulwark -- knight subclass.
-- Signature mechanic: Shove-lock -- knockback that also Halts the displaced. The immovable wall that
-- moves everyone else.
-- Exemplar: the Road-Captain (character_greywatch_captain), met as a MENTOR/ally -- a guard who holds
-- a line.
-- Gate: one quest in the knight (Bastion) line -- held_position. See docs/disciplines-plan.md.
return {
    name    = "Bulwark",
    description = "Moves foes and holds ground. Knockback pushes a foe back and inflicts Halt where it "
        .. "lands, and your own stance makes you immovable.",
    exemplar = "character_bulwark", -- was character_greywatch_captain (a story-disguised encounter unit); dedicated exemplar authored
    requires = { knight = 3 },
}
