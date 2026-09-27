-- KEEPER OF HORNS: the Oni Priestess's organ. Approved 2026-09-26 ("The Oni of Wrath"): "an oni beside her
-- can't have its horn snapped."
--
-- The flag is all of it (`keepsHorn`, read by trait_the_horn when a crit lands). It is what makes her the body
-- the company must answer before any plan to snap horns can work. Bound and unstealable.
return {
    name = "Keeper of Horns",
    description = "An oni beside you cannot have its horn snapped.",
    flavor = "She does not heal the horn. She reminds it what it is.",
    sprite = "assets/items/utility_keeper_of_horns.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_keeper_of_horns" },
}
