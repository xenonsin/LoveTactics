-- THE HYMN: the Herald's organ (reviewed 2026-09-30, "Pride's Bestiary"). At the end of its turn every ANGEL
-- within 2 of it is Blessed (trait_the_hymn, narrowed by `kin`). It is why a choir is worth breaking up, and why
-- the Herald -- the smallest body in it -- is the one to kill first.
--
-- Bound and unstealable: an organ, never kit. The company's copy is the Herald's Trumpet.
return {
    name = "The Hymn",
    description = "At the end of your turn, every angel within 2 is Blessed.",
    flavor = "One voice, held on one note, for as long as the choir needs it held.",
    sprite = "assets/items/utility_the_hymn.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_the_hymn" },
    traitParams = { kin = "angel" },
}
