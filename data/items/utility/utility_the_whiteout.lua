-- THE WHITEOUT: the Dread of the Whiteout's first organ (data/characters/character_dread_of_the_whiteout.lua;
-- trait_whiteout). Approved 2026-10-04 on "Sloth's Bestiary", slice A. The company can wear it as the Whiteout
-- Cloak.
return {
    name = "The Whiteout",
    description = "Unseen to foes more than 2 tiles away.",
    flavor = "The snow does not fall around her. It falls from her.",
    sprite = "assets/items/utility_the_whiteout.png",
    type = "utility",
    class = "creature",
    tags = { "natural" },
    bound = true,
    noSteal = true, -- a creature's body is not loot
    traits = { "trait_whiteout" },
}
