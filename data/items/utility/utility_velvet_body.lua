-- What a VELVET SLIME is (data/characters/character_velvet_slime.lua): the fen's Amorphous Body
-- (utility_amorphous_body) in Lust's keep. Proof against blades, points and blows, adapting to the
-- element that gets through -- and it takes your gear (trait_strip) and gives it back when it dies
-- (trait_wardrobe).
return {
    name = "Velvet Body",
    description = "Voids blades, points and blows. Its blows take your gear, and it gives it back when it falls.",
    flavor = "Soft all the way through, and it wants what you have on.",
    sprite = "assets/items/velvet_body.png",
    type = "utility",
    class = "creature",
    tags = { "relic" },
    bound = true,
    noSteal = true, -- a creature's body is not loot
    immune = { physical = true, slash = true, pierce = true, impact = true },
    traits = { "trait_adaptive", "trait_strip", "trait_wardrobe" },
}
