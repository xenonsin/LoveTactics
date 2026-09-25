-- THE MAST-ROPE's rule (data/items/utility/utility_mast_rope.lua): the bearer and every ally beside it are
-- anchored (Status.blocksForcedMove asks `lashes` of the body and its neighbours). It declares an empty
-- `presence` so Trait.presenceLive switches on the moment one exists -- the lash is read on the board,
-- and a game with no rope in it pays one boolean for the question.
return {
    name = "Mast-Rope",
    description = "You and every ally beside you cannot be shoved, pulled or thrown.",
    lashes = true,
    presence = { radius = 1 },
}
