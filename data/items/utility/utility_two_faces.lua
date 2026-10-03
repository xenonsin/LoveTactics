-- TWO FACES: the Faceless Colossus's organ (data/characters/character_faceless_colossus.lua). Reviewed 2026-10-01..03
-- ("Envy's Bestiary"). The heap wears the face Reshape picks, and the runner-up for the same read lends its kit into
-- the cells left free (trait_two_faces, models/masks.lua). Bound and unstealable.
return {
    name = "Two Faces",
    description = "Wear two faces at once: the one Reshape picks, and the next best one's kit beside it.",
    flavor = "Two of them, or more, gave up being separate. The heap remembers both faces and neither name.",
    sprite = "assets/items/utility_two_faces.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_two_faces" },
}
