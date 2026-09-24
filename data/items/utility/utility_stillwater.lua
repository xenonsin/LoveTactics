-- STILLWATER: one of the Glacier King's own. Its stillness, worn (trait_stillwater).
--
-- `unstocked`: the body's own piece, visible on its house's rack and never sold (docs/drops.md).
return {
    name = "Stillwater",
    description = "+3 Defense after a turn you didn't move.",
    flavor = "Nothing gets through still water. Nothing has to.",
    sprite = "assets/items/utility_stillwater.png",
    type = "utility",
    class = "knight",
    unlockLevel = 10,
    unstocked = true,
    tags = { "protective" },
traits = { "trait_stillwater" },
}
