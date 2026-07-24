-- Vow-Marked: the standing rule of the Paladin's plate. Every affliction the bearer takes on hardens
-- them -- a permanent lift to defense for each debuff that lands, for the rest of the battle.
--
-- This is the payoff half of Lay On Hands, and it was added because the author read that ability and
-- said the obvious thing about it: pulling an ally's poison onto yourself is interesting, and it needs
-- somewhere to go. Without this, taking a debuff off someone is pure charity -- you have moved the
-- problem and paid for the privilege. With it, the paladin's own body is the ward: the more it is
-- carrying, the harder it is to put down.
--
-- Hangs on onStatusApplied in the RECIPIENT role, so it fires for a debuff however it arrived -- an
-- enemy's poison, a hazard's chill, or one the paladin deliberately took off a friend. It never asks
-- where the affliction came from, which is what keeps it a vow rather than a trick.
--
-- Permanent for the battle rather than while-carried, deliberately: what hardens a paladin is having
-- BORNE the thing, and a bonus that lapsed the moment a Cure landed would punish the party for tending
-- to them.
return {
    name = "Vow-Marked",
    magnitude = 2, -- defense kept per affliction borne
    onStatusApplied = function(ctx)
        if ctx.role ~= "recipient" then return end
        local landed = ctx.status and ctx.status.def
        if not (landed and landed.debuff) then return end
        if not ctx.unit.alive then return end
        ctx.addBonus("defense", ctx.def.magnitude or 2)
    end,
    -- ...and when a comrade goes down, the vow answers with a ward rather than a stat.
    onAnyDeath = function(ctx)
        local fallen = ctx.fallen
        if not (fallen and ctx.unit.alive) then return end
        if fallen.side ~= ctx.unit.side or fallen == ctx.unit then return end
        require("models.status").apply(ctx.combat, ctx.unit, "status_aegis", { applier = ctx.unit })
        ctx.log("action", string.format("%s's vow closes over the gap.",
            (ctx.unit.char and ctx.unit.char.name) or "The paladin"), ctx.unit)
    end,
}
