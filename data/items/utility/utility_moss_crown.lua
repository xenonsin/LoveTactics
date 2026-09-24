-- The MOSS KING's relic (data/characters/character_moss_king_slime.lua): the Sovereign Mass
-- (data/items/utility/utility_sovereign_mass.lua) with the wood's softer skin -- see the Mossy Body
-- for why the wood's slimes resist steel rather than void it.
--
-- It divides into MOSS slimes, not fen ones, which is what `traitParams.spawn` is for: a king that
-- came apart into three bodies a sword cannot touch would hand the opening floor the exact wall this
-- variant exists to keep off it.
return {
    name = "Moss Crown",
    description = "Blades, points and blows barely get through. Takes on elements, and divides into three when it falls.",
    flavor = "It wears the wood the way the wood wears it.",
    sprite = "assets/items/moss_crown.png",
    type = "utility",
    class = "creature",
    tags = { "relic" },
    bound = true,
    noSteal = true, -- a creature's body is not loot
    resist = { slash = 12, pierce = 12, impact = 12 },
    traits = { "trait_adaptive", "trait_split" },
    traitParams = { spawn = "character_moss_slime" },
}
