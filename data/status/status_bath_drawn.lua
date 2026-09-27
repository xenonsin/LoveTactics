-- BATH DRAWN: the Blood Countess's basin is full (models/basin.lua). At the top of her next turn she bathes --
-- healed to full and Bathed -- and the basin empties. Break the basin before then and the bath is off.
local Basin = require("models.basin")

return {
    name = "Bath Drawn",
    abbr = "Bath",
    description = "The basin is full. At the start of her next turn she bathes, unless the basin is broken first.",
    color = { 0.900, 0.200, 0.260 }, -- badge tint (fresh blood)
    duration = math.huge,
    hideDuration = true,
    onTurnStart = function(ctx)
        Basin.onTurnStart(ctx.combat, ctx.unit, ctx.status)
    end,
}
