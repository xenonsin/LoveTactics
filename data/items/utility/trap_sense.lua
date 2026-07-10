-- A passive detector: reveals enemy traps within detectRadius (Manhattan) of its bearer. The
-- "detect traps" tag is exactly what Trap.visibleTo looks for; detectRadius overrides the default.
-- No active ability -- just carrying it grants the reveal.
return {
    name = "Trap Sense Charm",
    description = "Reveals hidden enemy traps within 2 tiles.",
    sprite = "assets/items/trap_sense.png",
    type = "utility",
    tags = { "detect traps" },
    class = "hunter",
    price = 150,
    repRank = 2,
    detectRadius = 2,
}
