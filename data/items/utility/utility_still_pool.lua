-- THE STILL POOL: the Water Mirror's organ (data/characters/character_the_water_mirror.lua). Reviewed 2026-10-01..03
-- ("Envy's Bestiary", the Frieren test). At the opening bell it makes an exact copy of every body in the company;
-- it never moves, and it takes nothing while a copy stands (trait_still_pool, models/masks.lua). `noMove` is the
-- engine's own rule for a body that never walks; Unmoved's flag on the trait keeps a shove from doing it instead.
return {
    name = "The Still Pool",
    description = "At the start of the fight, copy every foe. You cannot move, and take no damage while a copy stands.",
    flavor = "Nobody has ever seen the bottom. Everybody who looked saw somebody looking back.",
    sprite = "assets/items/utility_still_pool.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    rules = { noMove = true },
    traits = { "trait_still_pool" },
}
