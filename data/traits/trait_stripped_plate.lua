-- Stripped Plate: the standing rule of the Vanguard's charm of the same name. Armour the bearer breaks
-- off somebody else is worn by the bearer -- a defense bonus for every body it Sunders, for the rest of
-- the battle.
--
-- Hangs on onStatusApplied in the APPLIER role (models/status.lua fires the hook on both sides of a
-- landing, and `role` is how a reaction tells "I inflicted this" from "this landed on me"). So it does
-- not care WHICH way the armour came off: Shieldbreak, Pry Open, a Breaker's Wedge shove, or a sundering
-- parry all pay it, and any future source will too without touching this file.
--
-- It is the rogue half of the discipline doing greed's own verb on the knight half's mechanic. The
-- knight opens the plate; the rogue keeps it. Which is also why the bonus is permanent for the battle
-- rather than a timed buff -- taking is not a stance, and what you have taken you have.
--
-- Reads `magnitude` off the def so the forge can raise it, and is deliberately small per stack: the
-- Vanguard's Wedge makes Sunder common, and a large per-body bonus on a mechanic designed to fire
-- constantly is a different item than the one this is meant to be.
return {
    name = "Stripped Plate",
    description = "Every body you Sunder leaves you wearing its plate: defense kept for the battle.",
    magnitude = 2, -- defense kept per body Sundered
    onStatusApplied = function(ctx)
        if ctx.role ~= "applier" then return end
        if not (ctx.status and ctx.status.id == "status_sundered") then return end
        if not ctx.unit.alive then return end
        ctx.addBonus("defense", ctx.def.magnitude or 2)
        ctx.log("action", string.format("%s strips the broken plate and wears it.",
            (ctx.unit.char and ctx.unit.char.name) or "The vanguard"), ctx.unit)
    end,
}
