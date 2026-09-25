-- The apex LEARNS: the piece in Gula's grid that carries her Studied (data/traits/trait_studied.lua).
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
