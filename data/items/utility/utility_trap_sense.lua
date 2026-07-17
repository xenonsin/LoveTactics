-- A passive detector: reveals enemy traps within detectRadius (Manhattan) of its bearer. The
-- "detect traps" tag is exactly what Trap.visibleTo looks for; detectRadius overrides the default.
-- No active ability -- just carrying it grants the reveal.
return {
    name = "Trap Sense Charm",
    description = "Reveals hidden enemy traps near you.",
    flavor = "The Lodge charges for the charm. The lesson it replaces was free, and cost a foot.",
    sprite = "assets/items/trap_sense.png",
    type = "utility",
    tags = { "detect traps" },
    class = "hunter",
    price = 150,
    repRank = 2,
    detectRadius = 2,
}
