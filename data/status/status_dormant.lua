-- DORMANT: asleep with no countdown ("Sloth's Bestiary", 2026-10-04). Worn by the Old Sloth and by Desidia, who
-- both open a fight under it.
--
-- WHY NOT SLEEP. Sleep (status_sleep) is a shove down the turn order that ends on its own clock; a sleeper wakes
-- by itself sooner or later. A Dormant body does not: it takes no turns at all until a blow lands on it, and then
-- it wakes WORSE -- Rude Awakening, on the way out (onExpire, which every removal path runs). The company chooses
-- when that happens, which is the whole of the decision.
--
-- WHAT WAKES IT is a wound (onDamaged with an amount), and nothing else here. A body's own rule may wake it some
-- other way (Desidia's Stir) by removing the status; the Rude Awakening follows whichever way it goes.
--
-- Not a debuff and undispellable: it is on enemy bodies by their own design, and a Cure or a strip that woke a
-- boss for free would skip the decision.
return {
    name = "Dormant",
    abbr = "Dorm",
    description = "Dormant: asleep, and takes no turns. A blow wakes it, and it wakes worse.",
    color = { 0.420, 0.470, 0.640 }, -- badge tint (deep dusk)
    duration = math.huge,
    hideDuration = true,
    undispellable = true,
    disablesActions = true,
    blocksMove = true,
    disablesReactions = true,
    interruptsChannel = true,
    onDamaged = function(ctx)
        if (ctx.amount or 0) > 0 then ctx.expire() end
    end,
    onExpire = function(ctx)
        if ctx.unit and ctx.unit.alive then
            ctx.log("status", string.format("%s wakes, and it is not happy about it.",
                (ctx.unit.char and ctx.unit.char.name) or "Unit"))
            ctx.applyStatus(ctx.unit, "status_rude_awakening", { applier = ctx.unit })
        end
    end,
}
