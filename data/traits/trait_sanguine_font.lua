-- Sanguine Font: every time the bearer loses health on its OWN turn it banks a point of Blood (the
-- `blood` pool, declared on the item and fed by Engine.noteSelfWound's `selfWound` tally), and its
-- next ABILITY lands 3 harder per point. The ability that cashes it spends the whole pool.
--
-- The barbarian's Blood Price multiplier (docs/engines.md): Rupture, in a game where the self-wound is
-- a Red Tithe, a Wound Gift's price, or a blow answered back into the body mid-swing.
return {
    name = "Sanguine Font",
    description = "Each time you lose health on your turn, your next ability deals 3 more (up to 12).",
    perPoint = 3,
    damageBonusVs = function(ctx)
        if not (ctx.blow and ctx.blow.type == "ability") then return 0 end
        local n = require("models.combat").chargePool(ctx.unit, "blood")
        return n * ctx.param("perPoint", ctx.def.perPoint or 3)
    end,
    onCast = function(ctx)
        local cast = ctx.item
        -- Spent by the ability that CASHED it: one that drew blood. A Red Tithe paying in is an ability
        -- too, and must not throw away the point it just banked.
        if not (cast and cast.type == "ability" and (ctx.damageDealt or 0) > 0) then return end
        local Combat = require("models.combat")
        if Combat.chargePool(ctx.unit, "blood") > 0 then Combat.spendCharge(ctx.unit, "blood") end
    end,
}
