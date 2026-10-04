-- TOLL OF HOURS: Mora's rule (data/characters/character_mora.lua; mora is Latin for delay), and her drop's, the Toll
-- Ledger. Every ability used within reach of the bearer costs its user its next move as well: Rooted on its next
-- turn (models/toll.lua, Toll.owe / Toll.collect).
--
-- Heard on Trait.onAnyCast, the Gaunt Vigil's seam -- the one hook that fires on a working done by somebody else.
-- An ability is anything that is not a weapon's swing or a draught (Toll.isAbility): the Tollkeepers price what you
-- do, and a swing is what their own collectors do. The debt is collected as the debtor's next turn OPENS
-- (onAnyTurnStart), so the cast it just made resolves in full and the price lands on the turn after.
--
-- Params: `range` (4 for Mora, 3 for the Ledger) and `foesOnly` (the Ledger taxes foes; Mora taxes every user but
-- herself). A debt is held by any living bearer and forgiven when none is left to collect it.
return {
    name = "Toll of Hours",
    description = "An ability used within its reach costs its user its next move: Rooted on its next turn.",
    range = 4,
    notAReaction = true,
    onAnyCast = function(ctx)
        require("models.toll").owe(ctx.combat, ctx.unit, ctx.caster, ctx.castItem, ctx.param("range", 4),
            ctx.param("foesOnly", false))
    end,
    onAnyTurnStart = function(ctx)
        require("models.toll").collect(ctx.combat, ctx.actor)
    end,
}
