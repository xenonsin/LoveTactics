-- LULL: a warden's Lull, waiting for the end of the round (data/items/ability/ability_lull.lua; "Sloth's Bestiary",
-- slice G). Worn by the CASTER from the cast to the start of its next turn -- the round, in an engine with no rounds
-- -- and then every foe that did not move in it falls Asleep.
--
-- THE STATUS IS THE ROUND'S MEMORY. onApply notes how far every foe has walked so far (the `tilesMoved` and
-- `tilesBlinked` tallies); onTurnStart compares, puts the still ones under, and ends. A dry-run preview never
-- reaches onApply, so hovering the cast notes nothing.
--
-- Not a debuff: it is the caster's own working, and a Cure on the warden does not take it back.
local function stillness(u)
    local t = u.tally or {}
    return (t.tilesMoved or 0) + (t.tilesBlinked or 0)
end

return {
    name = "Lull",
    abbr = "Lull",
    description = "At the start of your next turn, every foe that did not move falls Asleep.",
    color = { 0.560, 0.600, 0.780 }, -- badge tint (dusk, Sleep's neighbourhood)
    duration = 9999,
    hideDuration = true,
    onApply = function(ctx)
        -- A list in board order, not a table keyed by body: the sleeps must land in the same order every replay.
        local seen = {}
        for _, u in ipairs((ctx.combat and ctx.combat.units) or {}) do
            if u.alive and u.side ~= ctx.unit.side then seen[#seen + 1] = { unit = u, moved = stillness(u) } end
        end
        ctx.status.seen = seen
    end,
    onTurnStart = function(ctx)
        for _, e in ipairs(ctx.status.seen or {}) do
            local u = e.unit
            if u.alive and u.side ~= ctx.unit.side and stillness(u) == e.moved then
                ctx.applyStatus(u, "status_sleep", { applier = ctx.unit })
            end
        end
        ctx.expire()
    end,
}
