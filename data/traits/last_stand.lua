-- A veteran who fights hardest cornered. The first time the bearer is driven below 40% health, it
-- throws up a physical barrier (negating the next physical blow) and finds +4 damage for the rest of
-- the battle. Once per fight: the `stacks` counter latches after it fires. Only on a SURVIVED hit
-- (onDamaged never runs on the killing blow), so it is a last stand, not a death rattle.
return {
    name = "Last Stand",
    description = "Falling below 40% health once: raise a barrier and gain +4 damage for the battle.",
    onDamaged = function(ctx)
        if ctx.trait.stacks > 0 then return end -- already made its stand this battle
        local hp = ctx.unit.char.stats.health
        if hp.max and hp.current / hp.max <= 0.40 then
            ctx.trait.stacks = 1
            ctx.applyStatus(ctx.unit, "physical_barrier")
            ctx.addBonus("damage", 4)
            ctx.log("action", string.format("%s makes a last stand!",
                (ctx.unit.char and ctx.unit.char.name) or "Unit"))
        end
    end,
}
