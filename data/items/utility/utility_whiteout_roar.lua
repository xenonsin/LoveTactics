-- WHITEOUT ROAR: the yeti's organ (data/characters/character_yeti.lua; trait_whiteout_roar). Approved 2026-10-04
-- on "Sloth's Bestiary", slice A. What the fight hands over is the Yeti-Hide Mantle, a smaller roar.
return {
    name = "Whiteout Roar",
    description = "At the start of its turn, each foe within 4 with no ally beside it is Rooted.",
    flavor = "Out in the white, it only ever sounds like it is right behind you.",
    sprite = "assets/items/utility_whiteout_roar.png",
    type = "utility",
    class = "creature",
    tags = { "natural" },
    bound = true,
    noSteal = true, -- a creature's body is not loot
    traits = { "trait_whiteout_roar" },
}
