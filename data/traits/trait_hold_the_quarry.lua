-- HOLD THE QUARRY: the Lioness's trophy rule (data/items/utility/utility_hold_the_quarry.lua), her hold turned
-- to work without a Lion: a blow that takes a foe from a quarter of its health or more to below it Roots it.
-- On the striker's side of the blow (Trait.onBlowLanded), so only a wound that crosses the line counts.
return {
    name = "Hold the Quarry",
    description = "A foe you bring below a quarter of its health is Rooted.",
    line = 0.25,
    onBlowLanded = function(ctx)
        local t = ctx.target
        local hp = t and t.char and t.char.stats and t.char.stats.health
        if not (hp and ctx.before) then return end
        local line = require("models.combat").unreservedMax(t.char, "health") * ctx.param("line", 0.25)
        if ctx.before >= line and hp.current < line then
            ctx.applyStatus(t, "status_root", { applier = ctx.unit })
        end
    end,
}
