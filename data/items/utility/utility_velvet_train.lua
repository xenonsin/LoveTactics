-- What the VELVET QUEEN is (data/characters/character_velvet_queen.lua): the Velvet Body, crowned. Her
-- blows take TWO pieces, and when she falls she comes apart into three velvet slimes wearing her
-- wardrobe between them (trait_velvet_split).
return {
    name = "Velvet Train",
    description = "Voids blades, points and blows. Her blows take two pieces; she divides wearing them.",
    flavor = "Everything she has on was somebody's.",
    sprite = "assets/items/velvet_train.png",
    type = "utility",
    class = "creature",
    tags = { "relic" },
    bound = true,
    noSteal = true, -- a creature's body is not loot
    immune = { physical = true, slash = true, pierce = true, impact = true },
    traits = { "trait_adaptive", "trait_strip", "trait_velvet_split" },
    traitParams = { takes = 2 },
}
