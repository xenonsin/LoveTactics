-- Druid -- hunter subclass.
-- Signature mechanic: Wildshape -- swap your kit for a beast form (bear = tank, wolf = speed) for N
-- turns. (ability_wild_shape_bear / _wolf are the first stock.)
-- Exemplar: a wild shapeshifter (character_druid, NEW -- pending), met as a MENTOR.
-- Gate: one quest in the hunter (Lodge) line -- the_manufactured_cull (slot 4).
-- A subclass opens no earlier than slot 3: a discipline handed over on a line's first or
-- second quest is not earned advancement, it is a welcome gift.
-- See docs/disciplines-plan.md.
return {
    name    = "Druid",
    description = "The shapeshifter. Trades your whole kit for a beast form for a few turns. Bear to hold ground, wolf to cover it.",
    classes = { "hunter" },
    exemplar = "character_druid", -- NEW, pending
    requiredLevel = { hunter = 4 },
}
