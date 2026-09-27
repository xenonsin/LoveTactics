-- SCATTERED: a bat flung out of the Thousand-Winged when it was struck down (models/swarm.lua's scatter), or one
-- of the swarm on the fight's first beat. For a turn it cannot fuse; when it lapses, the telegraph is redrawn.
return {
    name = "Scattered",
    abbr = "Scat",
    description = "Blown apart: cannot fuse with the other bats until this lapses.",
    color = { 0.420, 0.380, 0.460 }, -- badge tint (dusk)
    duration = 5, -- one turn at Status.TICKS_PER_TURN
    onExpire = function(ctx)
        if ctx.combat and ctx.unit and ctx.unit.alive then
            require("models.swarm").mark(ctx.combat, ctx.unit.side)
        end
    end,
}
