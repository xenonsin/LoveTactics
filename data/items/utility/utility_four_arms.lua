-- FOUR ARMS: the Asura Adept's organ (models/asura.lua). Arms are rank you can read off the sprite, and every
-- pair of them is one more landing on each bare-handed blow -- the field Swift Fist raises, so the Adept's
-- own Swift Fist stacks on top of it. Arms are never lost.
return {
    name = "Four Arms",
    description = "Bare-handed strikes land once more.",
    flavor = "Two to pray with. Two it kept for afterwards.",
    sprite = "assets/items/utility_four_arms.png",
    type = "utility",
    tags = { "natural", "fist" },
    class = "creature",
    noSteal = true,
    bound = true,
    arms = 4,
    unarmedBonus = { hits = 1 },
}
