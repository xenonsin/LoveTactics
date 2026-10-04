-- BAD DREAMS: the Sandman's organ for what his sleep leaves behind (data/characters/character_the_sandman.lua;
-- data/traits/trait_bad_dreams.lua). A body woken from his sleep by a blow is Rattled until the end of its next turn;
-- a Cure or the clock leaves none. Creature kit: bound, unstealable, on no shelf.
return {
    name = "Bad Dreams",
    description = "A body woken from his sleep by a blow is Rattled until the end of its next turn.",
    flavor = "Nobody remembers what it was. Everybody remembers who woke them.",
    sprite = "assets/items/utility_bad_dreams.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_bad_dreams" },
}
