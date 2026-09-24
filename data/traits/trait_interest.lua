-- INTEREST: opens the account at the bell (data/status/status_interest.lua). Greed's slime rule -- the
-- swamp's Slime and King Slime compound every turn they are left alive, harder and richer -- and the rule
-- two of their drops hand to a company.
--
-- The terms are the granter's (Trait.param), named `interest*` because a granter's traitParams reach
-- every trait on the item, and the King's relic also carries Comes Apart's `count` and `health`.
return {
    name = "Interest",
    description = "Each turn it lives it gains Damage, and it pays out more gold when it falls.",
    onCombatStart = function(ctx)
        local u = ctx.unit
        ctx.applyStatus(u, "status_interest")
        local s = require("models.status").get(u, "status_interest")
        if not s then return end
        s.step = ctx.param("interestStep", 2)
        s.gold = ctx.param("interestGold", 4)
        s.cap = ctx.param("interestCap", 6)
        s.paysNow = ctx.param("interestPaysNow", false)
        s.magnitude, s.turns, s.purse = 0, 0, 0
    end,
}
