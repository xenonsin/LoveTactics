-- UNFED MOUTH: a turn with nothing to eat makes the next one come sooner (trait_unfed, status_starving).
-- Carried by the Chimera's lion and its goat head; creature kit, no drop.
return {
    name = "Unfed Mouth",
    description = "A turn with nothing to do makes its next action come sooner.",
    flavor = "Hunger is patient for exactly as long as it has to be.",
    sprite = "assets/items/utility_unfed_mouth.png",
    type = "utility",
    class = "creature",
    tags = { "beast" },
    noSteal = true,
    traits = { "trait_unfed" },
}
