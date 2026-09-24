-- HAWK BELLS: what a falconer ties on a bird to find it in cover, and what finds a hider when you wear them
-- (data/traits/trait_hawk_bells.lua): an Invisible foe within 3 tiles of you can be targeted. The wood's hawk
-- drops them -- chosen on review (2026-09-23) over a Lure and a Hood, and an answer to the Sabertooths
-- hiding on the same floor. Trapper stock: the shelf that already sells finding what does not want to be
-- found.
return {
    name = "Hawk Bells",
    description = "Invisible foes within 3 tiles of you can be targeted.",
    flavor = "Two little bells on a strap. Everything in the wood knows exactly what they mean.",
    sprite = "assets/items/utility_hawk_bells.png",
    type = "utility",
    tags = { "charm" },
    class = "trapper",
    unlockLevel = 1,
    unstocked = true,
    traits = { "trait_hawk_bells" },
}
