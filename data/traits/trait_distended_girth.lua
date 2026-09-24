-- DISTENDED GIRTH: the Sated's fight turned around, for the Bulwark. You open Full x3 -- +2 Defense and -1
-- Movement a meal -- and each time you fall past another quarter of your health you shed one: a debuff
-- comes off with it, and the step it cost comes back. A tank that starts heavy and gets quicker and cleaner
-- as it is worn down. Approved on review (2026-09-23).
--
-- The quarters are counted DOWN from full (75%, 50%, 25%) and each is shed once a fight: a heal that climbs
-- back over a line does not refill the belly, which is the one thing that would make this a loop.
local Status = require("models.status")

local LINES = { 0.75, 0.50, 0.25 }

return {
    name = "Distended Girth",
    description = "Open with 3 meals (+2 defense, -1 movement each). Each quarter of health lost sheds one and a debuff.",
    meal = { defense = 2, movement = -1 },
    onCombatStart = function(ctx)
        ctx.trait.shed = 0
        Status.apply(ctx.combat, ctx.unit, "status_full", { magnitude = 3, statBonus = ctx.def.meal })
    end,
    onDamaged = function(ctx)
        local hp = ctx.unit.char.stats.health
        if not (hp.max and hp.max > 0) then return end
        local frac = hp.current / hp.max
        ctx.trait.shed = ctx.trait.shed or 0
        while ctx.trait.shed < #LINES and frac <= LINES[ctx.trait.shed + 1] do
            ctx.trait.shed = ctx.trait.shed + 1
            if not Status.spendStacks(ctx.combat, ctx.unit, "status_full", 1) then break end
            -- The newest debuff first: the thing that just landed is the thing worth shedding.
            local list = ctx.unit.statuses or {}
            for i = #list, 1, -1 do
                if list[i].def.debuff then Status.remove(ctx.combat, ctx.unit, list[i].id) break end
            end
            ctx.log("action", string.format("%s sheds a meal, and something with it.",
                (ctx.unit.char and ctx.unit.char.name) or "It"), ctx.unit)
        end
    end,
}
