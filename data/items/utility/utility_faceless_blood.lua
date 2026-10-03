-- A THOUSAND FACES: what a Faceless IS, granted by its race (data/races/faceless.lua) into the first free cell of
-- every Faceless ever minted. Reviewed 2026-10-01..03 ("Envy's Bestiary").
--
-- The bearer is dealt a hand of faces at the opening bell and wears the one that answers the nearest foe at the
-- top of every turn (models/faces.lua). Bound and unstealable, and carried into every face it puts on.
return {
    name = "A Thousand Faces",
    description = "Carry a hand of faces. Each turn, wear the one that best answers the nearest foe.",
    flavor = "Ask it who it is and it will ask who you need it to be.",
    sprite = "assets/items/utility_faceless_blood.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_a_thousand_faces" },
}
