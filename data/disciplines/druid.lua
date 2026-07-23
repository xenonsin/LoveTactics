-- Druid -- hunter subclass.
-- Signature mechanic: Wildshape -- swap your kit for a beast form (bear = tank, wolf = speed) for N
-- turns. (ability_wild_shape_bear / _wolf are the first stock.)
-- Exemplar: a wild shapeshifter (character_druid, NEW -- pending), met as a MENTOR.
-- Gate: one quest in the hunter (Lodge) line -- the_guide. See docs/disciplines-plan.md.
return {
    name    = "Druid",
    classes = { "hunter" },
    exemplar = "character_druid", -- NEW, pending
    requiredQuests = { "the_guide" },
}
