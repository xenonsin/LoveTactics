-- THE COMMUNION CHALICE: the Communicant's drop (data/items/utility/utility_communion_chalice.lua). At the end of
-- the bearer's turn it loses 5% of its max health and each ally beside it heals that much. The heal is a DRINK
-- (feeding), so it heals an undead ally instead of wounding it -- the one heal in a company's hands Grave-Cold
-- lets through.
local SHARE = 0.05

return {
    name = "Communion Chalice",
    description = "At the end of your turn, lose 5% of your max health; each adjacent ally heals that much.",
    notAReaction = true,
    onTurnEnd = function(ctx)
        local u, combat = ctx.unit, ctx.combat
        if not (u and u.alive and combat) then return end
        local Combat = require("models.combat")
        local allies = {}
        for _, other in ipairs(combat.units or {}) do
            if other.alive and other ~= u and other.side == u.side and Combat.unitGap(u, other) == 1 then
                allies[#allies + 1] = other
            end
        end
        if #allies == 0 then return end
        local pay = math.max(1, math.floor(Combat.unreservedMax(u.char, "health") * SHARE + 0.5))
        local paid = ctx.drain(u, "health", pay)
        if paid <= 0 then return end
        for _, a in ipairs(allies) do Combat.applyHeal(combat, a, paid, { feeding = true }) end
    end,
}
