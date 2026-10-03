-- TURNED TO STONE: what keeps a past challenger standing in Medusa's garden (data/characters/
-- character_stone_challenger.lua; trait_turned_to_stone). Creature kit: bound, unstealable, on no shelf.
return {
    name = "Turned to Stone",
    description = "Petrified until Medusa falls to half health.",
    flavor = "It came for her head. It is still holding the sword.",
    sprite = "assets/items/utility_turned_to_stone.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_turned_to_stone" },
}
