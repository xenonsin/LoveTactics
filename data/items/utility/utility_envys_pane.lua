-- The pane a Second Self is cast in, and the vessel Lesser Reflection rides in.
--
-- A creature's rule has to live on an ITEM in its grid -- a blueprint's own `traits` field is never
-- collected, only an item's is (models/trait.lua) -- which is the same reason each of the seven generals
-- is a relic plus a weapon rather than a stat block with a rule written on it.
--
-- Natural kit: no class, no price, noSteal, outside every shelf (tests/bestiary_spec.lua). It is the
-- glass the thing was poured into, still stuck to it.
return {
    name = "Envy's Pane",
    description = "Once wounded, it takes the shape of the weakest foe, and it fights for the mirror.",
    flavor = "The Crucible poured a hundred of these and kept none. They kept themselves.",
    sprite = "assets/items/envys_pane.png",
    type = "utility",
    class = "creature",
    dropTier = 2,
    tags = { "natural" },
    noSteal = true,
    traits = { "trait_lesser_reflection" },
}
