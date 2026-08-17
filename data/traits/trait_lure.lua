-- LURE: it pulls one body out of your line, and the forest is what makes that fatal.
--
-- The Lust circle's control rule. Charm already exists and already does the hard part; what this adds is
-- that the pull happens as the body ACTS, so it is attributable to something you can kill rather than
-- being weather.
--
-- WHY THE FOREST. The `glades` carve is open trails through thick cover (data/biomes/forest.lua), which
-- makes it the game's ambush board -- and a formation broken in cover is a formation fighting alone,
-- one body at a time, against things it cannot see. Every other circle's control costs you a turn; this
-- one costs you the shape of your company.
--
-- On a cooldown rather than every cast, because a Lure that fired constantly would be a lock rather than
-- a decision, and the counterplay (kill the Chorister, or close the gap it opened) needs turns to happen
-- in.
return {
    name = "Lure",
    description = "Charms a foe as it acts, then goes on cooldown.",
    cooldown = 14,
    onCast = function(ctx)
        -- Cooldowns are KEYED, so the id is passed on both sides -- an unkeyed call would share a slot
        -- with whatever else the bearer is tracking (see trait_opportunist for the same pair).
        if ctx.onCooldown("trait_lure") then return end
        local target = ctx.unitAt(ctx.tx, ctx.ty)
        if not target or not target.alive or target.side == ctx.unit.side then return end
        ctx.applyStatus(target, "status_charm")
        ctx.setCooldown("trait_lure", ctx.def.cooldown or 14)
        ctx.log("action", string.format("%s is called, and goes.",
            (target.char and target.char.name) or "Somebody"))
    end,
}
