-- THUNDERCLAP: the Arc's rule, and the Flashpan's (models/storm.lua; "Fire, Lightning, and Dirty Thunder",
-- 2026-09-27). The first body a bearer's LIGHTNING strikes each turn is Blinded -- the aimed body, not a fork.
-- Blindness is in Wrath's brief and nothing on the circle dealt it; it bites the archers and casters who can reach
-- an Arc across a flow.
local function lightning(item)
    for _, t in ipairs((item and item.tags) or {}) do
        if t == "lightning" then return true end
    end
    local ab = item and item.activeAbility
    for _, t in ipairs((ab and ab.tags) or {}) do
        if t == "lightning" then return true end
    end
    return false
end

return {
    name = "Thunderclap",
    description = "Your lightning inflicts Blind on the first body it strikes each turn.",
    onCast = function(ctx)
        -- ctx.item is the CAST item here (the event shadows the granting one).
        if not lightning(ctx.item) or (ctx.damageDealt or 0) <= 0 or not ctx.tx then return end
        local turn = ctx.combat and ctx.combat.turn
        if turn and turn.unit == ctx.unit then
            if turn.thunderclap then return end
            turn.thunderclap = true
        end
        local t = ctx.unitAt(ctx.tx, ctx.ty)
        if t and t ~= ctx.unit and t.alive then ctx.applyStatus(t, "status_blind") end
    end,
}
