-- SIX ARMS: the Three-Faced Asura's organ, and the Niō's (models/asura.lua). Three pairs, three landings on
-- every bare-handed blow. Arms are never lost.
return {
    name = "Six Arms",
    description = "Bare-handed strikes land twice more.",
    flavor = "Three faces, and a pair of hands for each of them to be angry with.",
    sprite = "assets/items/utility_six_arms.png",
    type = "utility",
    tags = { "natural", "fist" },
    class = "creature",
    noSteal = true,
    bound = true,
    arms = 6,
    unarmedBonus = { hits = 2 },
}
