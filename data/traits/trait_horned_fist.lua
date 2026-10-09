-- HORNED FIST: the oni monk's race item (data/items/utility/utility_horned_fist.lua, "The Rift's Adventurers",
-- slice D). The moment the bearer's horn comes out -- Horn Out, or the Full Horn Out an elder wears -- its chi
-- bank fills to the top (Combat.grantCharge onto the engine's own chi pool, which stops at the cap).
local HORNS = { status_horn_out = true, status_full_horn_out = true }

return {
    name = "Horned Fist",
    description = "When you Horn Out, your chi bank fills.",
    notAReaction = true,
    onStatusApplied = function(ctx)
        local u = ctx.unit
        if ctx.role ~= "recipient" or ctx.recipient ~= u then return end
        if not (ctx.status and HORNS[ctx.status.id]) then return end
        local Combat = require("models.combat")
        Combat.grantCharge(u, "chi", Combat.CHI_MAX)
    end,
}
