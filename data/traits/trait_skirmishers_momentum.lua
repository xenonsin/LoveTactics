-- Skirmisher's Momentum: the Skirmisher's passive (fighter x hunter). The first blow struck AFTER moving
-- lands harder -- the reward for kiting, hit-and-run made a standing rule. Reads the strike through the
-- damageBonusVs hook (a pure query summed into the pre-mitigation base, so it rides the hover preview),
-- and keys off the bearer having moved this turn (unit.hasMoved / unit.moved -- whichever the turn
-- tracks). Stand still and it gives nothing; that is the point.
return {
    name = "Skirmisher's Momentum",
    description = "Your first strike after moving deals extra damage.",
    bonus = 5, -- flat, pre-mitigation, when the bearer has moved this turn
    damageBonusVs = function(ctx)
        local u = ctx.unit
        if u and (u.hasMoved or u.moved) then return ctx.def.bonus or 5 end
        return 0
    end,
}
