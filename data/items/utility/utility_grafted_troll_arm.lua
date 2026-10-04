-- GRAFTED TROLL ARM: the Troll's second drop, on the Plague Knight's shelf. Approved 2026-10-04 ("Sloth's
-- Bestiary", slice B; the author spread the troll's drops across the line).
--
-- A tenth of your health back each turn, and a heal from your own side does nothing to you
-- (data/traits/trait_grafted_troll_arm.lua). A plague knight's because it is a body nobody else can tend.
--
-- `unstocked`: the body's own piece, visible on its house's rack and never sold (docs/drops.md).
return {
    name = "Grafted Troll Arm",
    description = "Regrow a tenth of your health each turn. Heals from allies do nothing to you.",
    flavor = "It took. That is the most anybody who has seen it will say about it.",
    sprite = "assets/items/utility_grafted_troll_arm.png",
    type = "utility",
    tags = { "charm" },
    class = "plague_knight",
    unlockLevel = 9,
    unstocked = true,
    traits = { "trait_grafted_troll_arm" },
}
