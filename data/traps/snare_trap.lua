-- Snare trap: roots the first opponent to cross its tile instead of dealing damage -- a
-- status-delivering trap. See models/trap.lua; ctx.applyStatus routes to models/status.lua.
return {
    name = "Snare Trap",
    sprite = "assets/traps/snare_trap.png",
    health = 4,
    tags = { "trap", "snare" },
    onTrigger = function(ctx)
        ctx.applyStatus(ctx.victim, "root")
    end,
}
