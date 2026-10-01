-- THE LAST LAMP: the rule on the Wishmaker's drop (utility_the_last_lamp). Reviewed 2026-09-30 ("Pride's
-- Bestiary").
--
-- Two hooks. onDamaged lights it: the first wound that leaves the bearer under a third of its health puts on
-- Djinn Form, once a fight. onAnyTurnEnd is the flight: while the form holds, a foe whose turn ends next to the
-- bearer sends it blinking clear (Djinn.escape -- the djinn's own blink, free, to the open tile within 4 farthest
-- from its foes). A foe's turn ENDING is the beat because a trait has no hook on somebody else's step; the blow
-- that foe came to land has landed, and the next one will not find the bearer there.
return {
    name = "The Last Lamp",
    description = "Once per fight, when you fall below a third of your health, become a djinn for 3 turns.",
    onDamaged = function(ctx)
        local u = ctx.unit
        if ctx.trait.lit or not (u and u.alive) then return end
        local hp = u.char.stats.health.current or 0
        local max = require("models.combat").unreservedMax(u.char, "health")
        if hp * 3 >= max then return end
        ctx.trait.lit = true
        ctx.applyStatus(u, "status_djinn_form", { applier = u })
    end,
    onAnyTurnEnd = function(ctx)
        local u, actor = ctx.unit, ctx.actor
        if not (u and u.alive and actor and actor.alive) or actor.side == u.side then return end
        if not require("models.status").has(u, "status_djinn_form") then return end
        if require("models.combat").unitGap(u, actor) ~= 1 then return end
        require("models.djinn").escape(ctx.combat, u, "%s blinks away to (%d, %d).")
    end,
}
