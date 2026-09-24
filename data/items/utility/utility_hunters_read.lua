-- The apex LEARNS: the piece that carries Gula's Studied (data/traits/trait_studied.lua) through both of
-- her bodies. It sits in the huntress's grid and again in the beast's, because a transform swaps the grid
-- whole (models/transform.lua) and a rule carried on one body's item would stop the moment she turned.
-- Settled on review 2026-09-23: "have her gain resistance every time she gets hit".
return {
    name = "Hunter's Read",
    description = "Each hit grants resistance to its damage type, replacing the last.",
    flavor = "The finest hunter the region ever produced. She has already seen you do that.",
    sprite = "assets/items/hunters_read.png",
    type = "utility",
    class = "creature",
    tags = { "natural" },
    noSteal = true,
    traits = { "trait_studied" },
}
