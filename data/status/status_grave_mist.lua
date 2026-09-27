-- GRAVE MIST: the Box of Grave-Earth caught a blow that would have downed its bearer (data/traits/
-- trait_grave_earth.lua). It has drifted back to the tile it opened the fight on, and nothing can touch it there:
-- no foe can aim at it and no blow lands. At the start of its next turn it re-forms at 30% of its health.
local TAGS = {
    "physical", "magical", "slash", "pierce", "impact", "fire", "cold", "lightning", "holy", "dark",
    "poison", "bleed", "acid", "arcane", "nature", "water", "wind", "earth",
}
local immune = {}
for _, t in ipairs(TAGS) do immune[t] = true end

return {
    name = "Grave Mist",
    abbr = "Mist",
    description = "Mist: cannot be targeted or hurt. Re-forms at 30% health at the start of its next turn.",
    color = { 0.520, 0.500, 0.560 }, -- badge tint (grey mist)
    duration = 99,          -- a fallback; it ends at the bearer's next turn
    hideDuration = true,
    untargetable = true,
    immune = immune,
    onTurnStart = function(ctx)
        local u = ctx.unit
        local Combat = require("models.combat")
        local hp = u.char.stats.health
        local want = math.max(1, math.floor(Combat.unreservedMax(u.char, "health") * 0.3 + 0.5))
        if hp.current < want then hp.current = want end
        ctx.log("action", string.format("%s re-forms.", (u.char and u.char.name) or "It"), u)
        ctx.expire()
    end,
}
