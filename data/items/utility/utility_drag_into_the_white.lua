-- DRAG INTO THE WHITE: the Dread of the Whiteout's second organ (data/characters/character_dread_of_the_whiteout.lua;
-- trait_drag_into_the_white). Approved 2026-10-04 on "Sloth's Bestiary", slice A. Her yeti Root; she takes.
return {
    name = "Drag Into the White",
    description = "At the start of its turn, hauls the nearest Rooted foe within 6 three tiles toward it.",
    flavor = "They find the tracks in spring. Only the one set, going out.",
    sprite = "assets/items/utility_drag_into_the_white.png",
    type = "utility",
    class = "creature",
    tags = { "natural" },
    bound = true,
    noSteal = true, -- a creature's body is not loot
    traits = { "trait_drag_into_the_white" },
}
