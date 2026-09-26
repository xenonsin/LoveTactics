-- THE DRYING CAP: the Redcap's rule (data/items/utility/utility_drying_cap.lua).
--
-- onCast marks the turn wet when a cast drew blood; onTurnEnd (the bearer's own turn, Trait.onAnyTurnEnd) bleeds
-- a dry turn for `dry` of max health, raw -- nothing softens a cap drying -- and then clears the mark for the
-- next turn. A kill the bearer made (the fallen's lastAttacker) heals `wet` of max health.
return {
    name = "The Drying Cap",
    description = "Lose 10% of your health at the end of each turn you drew no blood. A kill heals 25%.",
    notAReaction = true,
    dry = 0.10,
    wet = 0.25,
    onCast = function(ctx)
        if (ctx.damageDealt or 0) > 0 and ctx.unit then ctx.unit._capWet = true end
    end,
    onTurnEnd = function(ctx)
        local u = ctx.unit
        if not (u and u.alive) then return end
        if u._capWet then u._capWet = nil return end
        local Combat = require("models.combat")
        local loss = math.max(1, math.floor(Combat.unreservedMax(u.char, "health") * ctx.param("dry", 0.1) + 0.5))
        ctx.log("action", string.format("%s's cap is drying.", (u.char and u.char.name) or "It"), u)
        Combat.dealFlatDamage(ctx.combat, u, loss, { "bleed" }, "The Drying Cap", nil, { raw = true })
    end,
    onAnyDeath = function(ctx)
        local u, fallen = ctx.unit, ctx.fallen
        if not (u and u.alive and fallen and fallen.lastAttacker == u and fallen.side ~= u.side) then return end
        local Combat = require("models.combat")
        ctx.heal(u, math.floor(Combat.unreservedMax(u.char, "health") * ctx.param("wet", 0.25) + 0.5))
        u._capWet = true
    end,
}
