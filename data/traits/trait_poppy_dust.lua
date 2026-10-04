-- POPPY DUST: the Poppy-Moth's rule (data/items/utility/utility_poppy_dust.lua; "Sloth's Bestiary", 2026-10-04).
-- When a moth is struck, it bursts a cloud, and every body beside it falls Asleep, on either side.
--
-- ON ANY HIT, AND ON THE KILL. Lust's Swooncaps burst Swoon on DEATH; this bursts whenever it is struck and lays
-- Sleep, and a blow that fells it still shakes the dust off -- so a sword that kills a moth puts its own bearer
-- under. `notAReaction`: it is dust, not a reflex, so a moth the last cloud put to sleep still bursts when hit.
return {
    name = "Poppy Dust",
    description = "When struck, bursts: every body beside it falls Asleep, on either side.",
    notAReaction = true,
    onDamaged = function(ctx)
        if ctx.unit and ctx.unit.alive then require("models.sloth_dreamers").burst(ctx.combat, ctx.unit) end
    end,
    onDeath = function(ctx)
        if ctx.unit then require("models.sloth_dreamers").burst(ctx.combat, ctx.unit) end
    end,
}
