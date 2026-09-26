-- ORC SCARS: the Grunt's drop, round 2 (2026-09-26, "The Orcs of Wrath"). The race's own rule in a player's hand:
-- a kill makes you Proven, +2 Damage and +2 Defense for the fight, up to three times (trait_proven).
--
-- It replaced the Tally Bone, which carried its stacks through the trip and sat too close to the Trophy Cord, and
-- the Blooding Knife, which gave the stack to an ally. Keno's note on the choice: "I like the idea of killing to
-- raise your stats." It differs from the Cord three ways: every kill counts rather than kinds of foe, it lasts one
-- fight rather than the trip, and it buys Defense as well.
return {
    name = "Orc Scars",
    description = "A kill makes you Proven, up to 3 times.",
    flavor = "Cut in, not earned. The orcs would say there is no difference.",
    sprite = "assets/items/utility_orc_scars.png",
    type = "utility",
    tags = { "trinket" },
    class = "fighter",
    unlockLevel = 7,
    unstocked = true,
    traits = { "trait_proven" },
}
