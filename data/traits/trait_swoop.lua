-- SWOOP: the wood's hawk turns distance into damage -- +1 for every tile it crossed this turn before it
-- struck, up to +6. Approved on review (2026-09-23) as "Stoop"; that word is already the Wyvern's dive
-- (data/items/ability/ability_stoop.lua) and one word names one mechanic, so the hawk's is Swoop.
--
-- Its Talons still fly it back to where the turn began, so a hawk that crosses the field hits hard and
-- is not there to be hit back. The answer is standing where it cannot get a run.
return {
    name = "Swoop",
    description = "+1 damage for every tile flown this turn before the strike, up to +6.",
    cap = 6,
    damageBonusVs = function(ctx)
        local Combat = require("models.combat")
        return math.min(Combat.tilesMovedThisTurn(ctx.unit), ctx.param("cap", 6))
    end,
}
