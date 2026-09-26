-- FIREWALKER'S WRAPS: the Goblin Firebrand's feet, and the drop off it. Approved as pitched (2026-09-26, "The
-- Goblins of Wrath"): burning ground does not hurt you, and every tile you leave catches fire.
--
-- Two halves the shelf already sells apart -- the Cinderstride Boots' trail (the tile you step off is set
-- alight, ordinary unsided fire) and the Emberwalk Greaves' rule (fire on the ground does not harm you) -- and
-- a third that is the Firebrand's own: +3 damage while you stand in fire (trait_fire_fed). The three together
-- are the body, handed over whole, which is what a drop is (docs/drops.md). It brings its own fire, so it works
-- on any floor: walk a line across the board and you have built a wall, then stand in it.
return {
    name = "Firewalker's Wraps",
    description = "Fire on the ground does not harm you, and the tile you step off catches fire. Increase damage by 3 while in fire.",
    flavor = "Soot to the knee. It stopped noticing the heat a long time ago, and it never stopped liking it.",
    sprite = "assets/items/utility_firewalkers_wraps.png",
    type = "utility",
    tags = { "boots", "fire" },
    class = "bombardier",
    unlockLevel = 7,
    unstocked = true,
    trail = { hazard = "hazard_fire", duration = 8 },
    traits = { "trait_emberwalk", "trait_fire_fed" },
}
