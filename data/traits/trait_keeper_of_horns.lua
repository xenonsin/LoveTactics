-- KEEPER OF HORNS: the Oni Priestess's (utility_keeper_of_horns). trait_the_horn reads `keepsHorn` on any ally
-- beside an oni a critical hit just landed on, and keeps the horn whole.
return {
    name = "Keeper of Horns",
    description = "An oni beside you cannot have its horn snapped.",
    keepsHorn = true,
    notAReaction = true,
}
