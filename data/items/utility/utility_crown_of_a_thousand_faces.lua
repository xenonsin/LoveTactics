-- THE CROWN OF A THOUSAND FACES: the Many Faced One's organ (data/characters/character_general_envy.lua), and
-- what it is under every face it wears -- a crown with no head under it.
--
-- Carries the opener alone (trait_the_many_faced): the forms are chosen and the first is put on at the bell. The
-- rest of the fight rides on status_many_faced, which a form cannot take off. Bound and unstealable; nothing
-- drops it -- the relic is the Pretender's Crown (Descent.DROPS).
return {
    name = "Crown of a Thousand Faces",
    description = "Wear each general above Envy in turn, one share of health each, then split into a copy of each foe.",
    flavor = "Every face on it is somebody's. None of them is the one underneath.",
    sprite = "assets/items/utility_crown_of_a_thousand_faces.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_the_many_faced" },
}
