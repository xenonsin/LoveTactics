-- Defending: a temporary boost to physical defense from taking a defensive stance (the Defend
-- wait-behavior, granted by a shield). The bonus is the status's MAGNITUDE, folded into the unit's
-- effective defense via combat's flatStat (see Status.statBonus + `magnitudeStat` below). The
-- granting shield sets how much through its `waitBehavior.defense`, which scales with the shield's
-- upgrade level (Combat.defend passes it as the magnitude); this `magnitude` here is the fallback
-- for a shield that names none. It lasts exactly until the unit's NEXT turn: onTurnStart self-expires
-- it (the first turn-start after Defend is the following turn, since Defend itself ends the turn).
-- The `duration` is a generous fallback so it can never get stuck if that turn never comes.
return {
    name = "Defending",
    abbr = "Def",
    description = "Braced: raised physical defense until this unit's next turn.",
    color = { 0.466, 0.630, 0.795 }, -- badge tint (blue)
    duration = 99,          -- generous fallback; it really ends via onTurnStart (see below)
    hideDuration = true,    -- the fallback countdown is meaningless -- hide it in the tooltip
    magnitude = 8,          -- default +defense when the granting shield sets no waitBehavior.defense
    magnitudeStat = "defense", -- the flat stat this status's magnitude raises (via Status.statBonus)
    onTurnStart = function(ctx)
        -- BRACE (data/items/ability/ability_brace.lua, 2026-10-15): a brace this bearer LENT comes down as its
        -- own turn opens, whatever became of the bearer's own -- first, so a body that was lent a brace and
        -- lent one on in turn still takes its own loan down on time. Idempotent beside the Barrier's release.
        if ctx.combat then
            require("models.status").removePointingAt(ctx.combat, "status_defending", "heldBy", ctx.unit)
        end
        -- SLOTH'S TOLLKEEPERS, SLICE F (2026-10-04): a brace LENT by a barrier (the Bailiff, the Bailiff's Bar)
        -- holds until the lender's next turn, not the bearer's -- stamped `heldBy`, taken down by the lender's
        -- own turn opening (models/toll.lua). A lender gone from the field holds nothing up -- and neither does
        -- one whose own brace is gone, since the release above rides that brace's turn start.
        local by = ctx.status.heldBy
        if by and by ~= ctx.unit and by.alive and require("models.status").has(by, "status_defending") then
            return
        end
        ctx.expire()
    end,
}
