-- DEEPER PEAT: the Cairn-Keeper's organ (data/characters/character_cairn_keeper.lua; "Sloth's Bestiary",
-- 2026-10-04, slice C). Within 3 of the Keeper the Bog-Bound's rule is doubled -- a threshold of 16 and a
-- 4-movement toll (trait_deeper_peat; models/sloth_bog.lua). The Keeper carries the line's own organ beside it.
--
-- Bound and unstealable: the peat is where it stands, not a thing it holds. What the fight hands over is the
-- Cairn Stone, on the body's `drops`.
return {
    name = "Deeper Peat",
    description = "Within 3 of you, the Bog-Bound's rule is doubled: a threshold of 16, and a 4-movement toll.",
    flavor = "It keeps the oldest grave in the mire, and the mire is deepest there.",
    sprite = "assets/items/utility_deeper_peat.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_deeper_peat" },
}
