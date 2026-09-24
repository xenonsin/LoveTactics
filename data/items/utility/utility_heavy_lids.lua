-- HEAVY LIDS: one of the Glacier King's own. The frost slime's Numb, carried (trait_numb).
--
-- `unstocked`: the body's own piece, visible on its house's rack and never sold (docs/drops.md).
return {
    name = "Heavy Lids",
    description = "Your hits inflict Numbed, up to 3 stacks.",
    flavor = "Just five more minutes. For them.",
    sprite = "assets/items/utility_heavy_lids.png",
    type = "utility",
    class = "knight",
    unlockLevel = 10,
    unstocked = true,
    tags = { "offensive" },
traits = { "trait_numb" },
}
