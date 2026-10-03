-- SCALE OF HEARTS: the Jackal Weighers' trophy (data/characters/character_jackal_weigher.lua), on the
-- Inquisitor's shelf. Approved on "Envy's Bestiary", round 2. The scale turned on the bearer's own blows: a foe
-- with more current health than the bearer is struck for 4 more (trait_scale_of_hearts).
--
-- `unstocked`: the body's own piece, visible on its house's rack and never sold (docs/drops.md).
return {
    name = "Scale of Hearts",
    description = "Your blows deal +4 against a foe with more current health than you.",
    flavor = "The Inquisition has always weighed people. This is the first scale it has owned that admits it.",
    sprite = "assets/items/utility_scale_of_hearts.png",
    type = "utility",
    tags = { "charm" },
    class = "inquisitor",
    unlockLevel = 11,
    unstocked = true,
    traits = { "trait_scale_of_hearts" },
}
