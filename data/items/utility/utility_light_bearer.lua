-- LIGHT-BEARER: Superbia's fame, and her Reflections' (reviewed over three rounds, "Pride's Generals"). A foe whose
-- turn opens able to see the bearer is Blinded until that turn ends (trait_light_bearer).
--
-- Bound and unstealable: an organ, never kit. The Halo of the Morning carries the same rule for a crusader.
return {
    name = "Light-Bearer",
    description = "Foes that start their turn able to see you are Blinded until it ends.",
    flavor = "Her name meant the one who carries the light. She has never once set it down.",
    sprite = "assets/items/utility_light_bearer.png",
    type = "utility",
    tags = { "natural", "holy" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_light_bearer" },
}
