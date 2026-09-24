-- MIRROR MASK: one of the Many-Faced King's own (data/characters/character_many_faced_king.lua).
--
-- `unstocked`: the body's own piece, visible on its house's rack and never sold (docs/drops.md).
return {
    name = "Mirror Mask",
    description = "Each battle opens with a fragile copy of you beside you; the first blow meant for you hits it instead.",
    flavor = "Which one of you is it looking at?",
    sprite = "assets/items/utility_mirror_mask.png",
    type = "utility",
    class = "alchemist",
    unlockLevel = 12,
    unstocked = true,
    tags = { "protective" },
traits = { "trait_mirror_mask" },
}
