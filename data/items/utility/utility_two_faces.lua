-- TWO FACES: the Faceless Colossus's organ (data/characters/character_faceless_colossus.lua). Reviewed 2026-10-01..03
-- ("Envy's Bestiary"). The heap wears the face Reshape picks, and the runner-up for the same read lends its kit into
-- the cells left free (trait_two_faces, models/masks.lua). Bound and unstealable. Using the lent kit opens a seam,
-- and a blow through it tears the second face off for good (creature identity pass, 2026-11-19).
return {
    name = "Two Faces",
    description = "Wears a second face's kit beside its own. Using that kit opens a seam; the next blow tears the kit off for good.",
    flavor = "Two of them, or more, gave up being separate. The heap remembers both faces and neither name.",
    sprite = "assets/items/utility_two_faces.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_two_faces" },
}
