-- THE DREAMER: Desidia's organ, carrying the Long Sleep and its phase two (data/characters/character_general_sloth.lua;
-- data/traits/trait_the_dreamer.lua; models/desidia.lua). Creature kit: bound, unstealable, on no shelf. What a
-- company takes off her instead is the Long Sleep, her relic, on a knight's rack.
return {
    name = "The Dreamer",
    description = "Sleeps, banking a turn a round. The board's noise or a blow wakes her, and every banked turn sweeps a row.",
    flavor = "The glacier is the lid. Nobody has asked what is in the box.",
    sprite = "assets/items/utility_the_dreamer.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_the_dreamer" },
}
