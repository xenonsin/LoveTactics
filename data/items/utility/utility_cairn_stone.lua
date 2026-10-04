-- CAIRN STONE: the Cairn-Keeper's trophy, on the Warlord's shelf ("Sloth's Bestiary", 2026-10-04, slice C).
-- While the bearer stands, allies within 3 cannot be moved, Charmed or Taunted (trait_cairn_stone). The stone
-- that held the oldest grave in the mire down, carried to the front of a line instead.
--
-- `unstocked`: the body's own piece, visible on its house's rack and never sold (docs/drops.md).
return {
    name = "Cairn Stone",
    description = "While you stand, allies within 3 cannot be moved, Charmed or Taunted.",
    flavor = "It held one body down for a thousand years. It is not particular about whose.",
    sprite = "assets/items/utility_cairn_stone.png",
    type = "utility",
    tags = { "charm" },
    class = "warlord",
    unlockLevel = 9,
    unstocked = true,
    traits = { "trait_cairn_stone" },
}
