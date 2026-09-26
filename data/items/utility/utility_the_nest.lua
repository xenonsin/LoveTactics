-- THE NEST: the Brood Queen's own ground -- a heap rolled into her goes into her hoard (trait_the_nest).
-- A natural piece: creature kit, no price, noSteal.
return {
    name = "The Nest",
    description = "Starts with 10 Hoard; a coin heap rolled into it or beside it is added to its Hoard.",
    flavor = "Everything the colony carries comes here, and nothing comes back out whole.",
    sprite = "assets/items/utility_the_nest.png",
    type = "utility",
    class = "creature",
    tags = { "beast" },
    noSteal = true,
    traits = { "trait_the_nest" },
}
