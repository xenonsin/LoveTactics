-- SNOW-SLEEP: the Yuki-onna's breath on a traveller who stopped walking ("Sloth's Bestiary", 2026-10-04, approved).
-- Carried on her organ (utility_snow_sleep) and on White Silence, the elementalist's drop -- one rule, two bearers.
--
-- A FOE THAT ENDS ITS TURN WITHIN 3 OF THE BEARER WITHOUT HAVING MOVED gains Drowsy (status_drowsy, the foundation's);
-- at 3 Drowsy it falls Asleep, by Drowsy's own rule. Judged on the turn's END (onAnyTurnEnd), so it is the turn a
-- body chose to stand through that counts, and "moved" is the turn's own record: a walk spent, or a body that ends
-- somewhere other than where it started. A Wait without a step is standing still.
--
-- The answer is to keep moving, which is a thing to do rather than a thing to wait out. `notAReaction`: a stunned
-- snow woman still breathes.
local RANGE = 3

return {
    name = "Snow-Sleep",
    description = "A foe that ends its turn within 3 without having moved gains Drowsy. At 3 Drowsy it falls Asleep.",
    notAReaction = true,
    range = RANGE,
    onAnyTurnEnd = function(ctx)
        local me, actor, combat = ctx.unit, ctx.actor, ctx.combat
        if not (me and me.alive and actor and actor.alive and actor.side ~= me.side) then return end
        if actor.summoned and actor.timeless then return end
        local Combat = require("models.combat")
        if Combat.isOffTile(actor) or Combat.unitGap(me, actor) > ctx.param("range", RANGE) then return end
        local turn = combat and combat.turn
        if turn and turn.unit == actor then
            if turn.moved then return end
            if turn.startX and (turn.startX ~= actor.x or turn.startY ~= actor.y) then return end
        end
        ctx.applyStatus(actor, "status_drowsy", { applier = me })
    end,
}
