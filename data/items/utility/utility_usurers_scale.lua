-- THE USURER'S SCALE: one of the King Slime's own (data/characters/character_king_slime.lua). His
-- interest, charged to somebody else: every hit makes the foe Owed one more point from every hit after
-- it, up to six (trait_usurers_scale).
--
-- `unstocked`: visible on the Undercroft's rack and never sold (docs/drops.md).
return {
    name = "Usurer's Scale",
    description = "Your hits inflict Owed on the foe, up to 6 stacks.",
    flavor = "Weighed once. Weighed again. Weighed heavier.",
    sprite = "assets/items/utility_usurers_scale.png",
    type = "utility",
    tags = { "offensive" },
    class = "rogue",
    unlockLevel = 6,
    unstocked = true,
    traits = { "trait_usurers_scale" },
}
