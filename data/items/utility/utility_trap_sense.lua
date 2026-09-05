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
    class = "trapper", -- deeper cut of the shelf: buyable only once the trapper gate is cleared
    unlockQuests = 2,
    dropTier = 1,
    detectRadius = 2,
    -- knowing where the ground is bad is what luck looks like from outside
    bonus = { luck = 2 },
}
