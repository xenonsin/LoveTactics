-- BOG-BOUND: the line's organ, carried by every one of the Bog-Bound -- the mummies and bog bodies laid in the
-- frozen mire of Sloth's approach ("Sloth's Bestiary", 2026-10-04, slice C; both halves approved together).
--
--   PAST FEELING     a blow of 8 damage or less does nothing; anything heavier lands in full (trait_past_feeling)
--   THE MIRE HOLDS   a foe that starts its turn beside one pays 2 movement to step away from it; a shove or a
--                    pull pays nothing (trait_the_mire_holds)
--
-- Carried in the grid rather than granted by a race: the Bog-Bound are undead, and a race is coarse on purpose
-- (data/races/undead.lua) -- a skeleton is not made of peat. Bound and unstealable: a body, not kit.
return {
    name = "Bog-Bound",
    description = "A blow of 8 damage or less does nothing. A foe that starts its turn beside you pays 2 movement to leave.",
    flavor = "The peat kept everything about them except the part that minded.",
    sprite = "assets/items/utility_bog_bound.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_past_feeling", "trait_the_mire_holds" },
}
