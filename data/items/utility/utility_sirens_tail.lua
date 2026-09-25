-- What a SIREN is below the water line (data/characters/character_siren.lua): the naga's Coils in a
-- singer's body. Water costs a tile, deep water is her road, and she cannot drown or be soaked. Bound
-- and unstealable -- swimming never comes off a corpse; the Undertow's Gillscale Wrap is the MADE thing.
return {
    name = "Siren's Tail",
    description = "Water costs one tile to cross and deep water can be entered. You cannot drown.",
    flavor = "Nobody who has seen it has described it the same way twice.",
    sprite = "assets/items/utility_sirens_tail.png",
    type = "utility",
    tags = { "natural", "swim" },
    class = "creature",
    noSteal = true,
    bound = true,
    statusImmunity = { "status_wet" },
}
