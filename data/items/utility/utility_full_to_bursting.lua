-- FULL TO BURSTING: the Gorged's organ (trait_full_to_bursting, models/gorged.lua). Wrath's vampires, 2026-09-26/27.
-- It drank until it filled the room: every wound spills a pool of what it drank, and at half health the whole of it
-- comes out at once. Bound and unstealable: an organ, not kit.
return {
    name = "Full to Bursting",
    description = "Each wound spills a blood pool. At half health, burst: flood the tiles around you, shrink, speed up, Bloodlust for good.",
    flavor = "It stopped drinking when there was no more room, and there has been no room for a long time.",
    sprite = "assets/items/utility_full_to_bursting.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_full_to_bursting" },
}
