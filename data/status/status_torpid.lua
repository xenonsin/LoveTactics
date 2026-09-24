-- TORPID: Sloth's Torpor, as a badge (data/traits/trait_torpid_touch.lua). Its landing pushes the bearer's next
-- turn back by `magnitude` ticks -- a gentle Stun that does not disable anything -- and it moves 1 less
-- while it lasts. Each landing shoves again, so a company caught by several rime slimes loses whole turns.
return {
    name = "Torpid",
    abbr = "Torp",
    description = "Torpid: its next turn comes later, and it moves 1 less.",
    color = { 0.600, 0.760, 0.860 }, -- badge tint (hoarfrost)
    duration = 10,
    debuff = true,
    magnitude = 3,
    shovesInitiative = "magnitude",
    statBonus = { movement = -1 },
    onApply = function(ctx)
        ctx.unit.initiative = ctx.unit.initiative + (ctx.magnitude or 0)
    end,
}
