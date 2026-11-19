-- FOUR ARMS: the Asura Adept's organ (models/asura.lua). Arms are rank you can read off the sprite, and every
-- pair of them is one more landing on each bare-handed blow -- the field Swift Fist raises, so the Adept's
-- own Swift Fist stacks on top of it. Arms are never lost.
--
-- AND IT GATHERS WHEN LEFT ALONE (`idleHeats`, 2026-11-19, the creature identity pass). The audit found the Adept
-- was the Acolyte's lever with more hits; now a turn in which nothing struck it and it struck nothing banks 2 chi
-- instead of draining 1. Ignoring an Adept heats it, which is the Acolyte's lesson turned over: keep a body on it,
-- or burst it before it bursts.
return {
    name = "Four Arms",
    description = "Bare-handed strikes land once more. A turn it neither strikes nor is struck, it gains 2 chi instead of cooling.",
    flavor = "Two to pray with. Two it kept for afterwards.",
    sprite = "assets/items/utility_four_arms.png",
    type = "utility",
    tags = { "natural", "fist" },
    class = "creature",
    noSteal = true,
    bound = true,
    arms = 4,
    unarmedBonus = { hits = 1 },
    idleHeats = 2,
}
