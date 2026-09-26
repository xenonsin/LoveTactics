-- WARPAINT's rule (data/items/utility/utility_warpaint.lua), the Unbroken streak on any weapon -- Keno's round-2
-- note on the Berserker's drop: "I'd also like a similar utility". +2 Damage for each turn in a row you landed a
-- hit with anything, up to +10. Shares the Unbroken badge with the axe; the longer streak counts
-- (models/streak.lua).
return {
    name = "Warpaint",
    description = "Each turn in a row you land a hit, increase damage by 2, up to 10. A turn without one resets it.",
    notAReaction = true,
    onCast = function(ctx)
        if (ctx.damageDealt or 0) > 0 and ctx.unit then require("models.streak").hit(ctx.unit, "paint") end
    end,
    onTurnEnd = function(ctx) require("models.streak").settle(ctx.combat, ctx.unit, "paint") end,
}
