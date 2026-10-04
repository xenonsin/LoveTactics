-- MERIDIAN CHARM: the Noonday Demon's trophy, on the Inquisitor's shelf ("Sloth's Bestiary", 2026-10-04, slice C).
-- Foes within 3 that deal no damage on their turn gain Listless: -3 Damage a stack, until they deal some
-- (trait_meridian_charm). The Inquisition has always asked what a body was doing with its afternoon.
--
-- `unstocked`: the body's own piece, visible on its house's rack and never sold (docs/drops.md).
return {
    name = "Meridian Charm",
    description = "Foes within 3 that deal no damage on their turn gain Listless.",
    flavor = "A sun on a cord, stopped at noon. It asks every hand near it what it has done today.",
    sprite = "assets/items/utility_meridian_charm.png",
    type = "utility",
    tags = { "charm" },
    class = "inquisitor",
    unlockLevel = 9,
    unstocked = true,
    traits = { "trait_meridian_charm" },
}
