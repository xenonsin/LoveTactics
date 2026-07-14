-- Feather Boots: tread so light that traps never spring underfoot. A passive keyed off the "ignore
-- traps" tag, which Combat.ignoresTraps scans for at the trap chokepoint (Combat.enterTile) -- so the
-- wearer crosses any trap unharmed, whether it walked, was shoved, or was conjured onto one. Hazards
-- (fire, quicksand) still bite: the boots dodge blades, not the ground itself.
return {
    name = "Feather Boots",
    description = "Tread so light that traps never spring underfoot -- yours or the enemy's.",
    sprite = "assets/items/feather_boots.png",
    type = "utility",
    tags = { "boots", "ignore traps" },
    class = "rogue",
    price = 220,
    repRank = 2,
}
