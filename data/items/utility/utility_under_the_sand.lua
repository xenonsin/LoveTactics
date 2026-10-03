-- UNDER THE SAND: Leviathan's organ (data/characters/character_leviathan.lua), carrying its whole rule
-- (data/traits/trait_under_the_sand.lua; models/leviathan.lua). Creature kit: bound, unstealable, on no shelf.
-- What a company takes off it instead are the Undertow and Leviathan's Wake.
return {
    name = "Under the Sand",
    description = "Rises under the Fairest's 3x3, shoving all out; it becomes quicksand. Below half, its tail marks a second.",
    flavor = "The waste has no sea. Something under it has never been told.",
    sprite = "assets/items/utility_under_the_sand.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_under_the_sand" },
}
