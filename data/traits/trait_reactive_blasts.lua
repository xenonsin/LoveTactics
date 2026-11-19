-- Reactive Blasts: a bomb the bearer throws leaves its footprint as REACTION ground (the Bombardier's
-- compound of the alchemist's Reactions, docs/engines.md). An ice bomb leaves Rime (Chilled), a lightning
-- bomb leaves Shallows (Wet), an acid bomb or an oil flask leaves an Oil Slick (Oiled), and whoever the
-- blast caught already wears it. Every bomb becomes the setup for somebody else's payoff.
local GROUND = {
    { tag = "ice", hazard = "hazard_rime", status = "status_chilled" },
    { tag = "lightning", hazard = "hazard_shallows", status = "status_wet" },
    { tag = "acid", hazard = "hazard_oil_slick", status = "status_oiled" },
    { tag = "oil", hazard = "hazard_oil_slick", status = "status_oiled" },
}

local function has(tags, want)
    for _, t in ipairs(tags or {}) do
        if t == want then return true end
    end
    return false
end

return {
    name = "Reactive Blasts",
    description = "Your bombs leave reaction ground: ice leaves Chilled, lightning leaves Wet, acid and oil leave Oiled.",
    onCast = function(ctx)
        local item, ab = ctx.item, ctx.ability
        if not (item and ab and item.type == "consumable" and ab.aoe and ctx.tx) then return end
        local ground
        for _, g in ipairs(GROUND) do
            if has(item.tags, g.tag) then ground = g break end
        end
        if not ground then return end
        local Combat = require("models.combat")
        for _, c in ipairs(Combat.aoeCells(ctx.combat, ab, ctx.tx, ctx.ty, ctx.unit) or {}) do
            ctx.placeHazard(c.x, c.y, ground.hazard, { duration = 20 })
            local u = Combat.unitAt(ctx.combat, c.x, c.y)
            if u and u.alive then ctx.applyStatus(u, ground.status, { applier = ctx.unit }) end
        end
    end,
}
