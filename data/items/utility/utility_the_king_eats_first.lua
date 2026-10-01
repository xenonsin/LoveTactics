-- THE KING EATS FIRST: the Lioness's organ (data/characters/character_lioness.lua; trait_the_king_eats_first).
-- While a Lion of her side stands, her blows leave a foe at 1 and Rooted, held for him. Bound and unstealable.
return {
    name = "The King Eats First",
    description = "While a Lion of her side stands, her blows cannot take a foe below 1 health, and a foe she brings to 1 is Rooted.",
    flavor = "She does the running. He does the eating. Nobody in the pride has ever asked why.",
    sprite = "assets/items/utility_the_king_eats_first.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_the_king_eats_first" },
}
