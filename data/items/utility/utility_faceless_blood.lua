-- A THOUSAND FACES: what a Faceless IS, granted by its race (data/races/faceless.lua) into the first free cell of
-- every Faceless ever minted. Reviewed 2026-10-01..03 ("Envy's Bestiary").
--
-- The bearer is dealt a hand of faces at the opening bell and wears the one that answers the nearest foe at the
-- top of every turn (models/faces.lua). Bound and unstealable, and carried into every face it puts on.
--
-- And it is where the race's tell rides (creature identity pass, 2026-11-19): an impact blow knocks a face Reshape
-- chose clean off, and the body is Unmasked until its turn ends (Faces.knockOff, status_unmasked).
return {
    name = "A Thousand Faces",
    description = "Each turn, wears the face that best answers the nearest foe. An impact blow knocks it off until its turn ends.",
    flavor = "Ask it who it is and it will ask who you need it to be.",
    sprite = "assets/items/utility_faceless_blood.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_a_thousand_faces" },
}
