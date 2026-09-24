-- SECOND SELF: one of the Many-Faced King's own (data/characters/character_many_faced_king.lua).
--
-- `unstocked`: the body's own piece, visible on its house's rack and never sold (docs/drops.md).
return {
    name = "Second Self",
    description = "When you fall, a copy of you with half your health fights on for two turns.",
    flavor = "It was always the better of the two of you.",
    sprite = "assets/items/utility_second_self.png",
    type = "utility",
    class = "alchemist",
    unlockLevel = 12,
    unstocked = true,
    tags = { "protective" },
traits = { "trait_second_self" },
}
