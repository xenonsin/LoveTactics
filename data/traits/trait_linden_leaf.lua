-- The Linden Leaf's one open spot (data/items/utility/utility_linden_leaf.lua).
--
-- At the bell, one of the three physical tags is rolled off the fight's own dice (Combat.roll, so a replay
-- deals the same spot) and the bearer wears that tag's Vulnerable status for the fight -- the existing
-- badge (data/status/status_vulnerable_slash.lua and its two siblings), so the weak spot is shown rather
-- than remembered, and the enemy's planner reads it like any other.
local SPOTS = { "slash", "pierce", "impact" }

return {
    name = "Linden Leaf",
    description = "When a fight starts, one physical tag is chosen: you are Vulnerable to it for the fight.",
    onCombatStart = function(ctx)
        local combat, unit = ctx.combat, ctx.unit
        if not (combat and unit and unit.alive) then return end
        local Combat = require("models.combat")
        local Status = require("models.status")
        local tag = SPOTS[Combat.roll(combat, #SPOTS)]
        Status.apply(combat, unit, "status_vulnerable_" .. tag, { duration = math.huge })
    end,
}
