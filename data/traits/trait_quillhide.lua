-- QUILLHIDE: a coat sewn with barbs. A foe that strikes its wearer in MELEE comes away with a quill in it
-- (status_quilled) -- read off the blow's own `melee` tag, which every close weapon carries, so a spray,
-- a burn tick or an arrow answers nothing.
--
-- No damage and no roll: the barb is already in the coat, and the blow that found it is the one that
-- landed. That is what keeps it a setup rather than a thorn -- the payoff is every pierce blow the
-- company throws at that foe afterwards, two points a quill. Granted by armor_quillhide, the manticore's
-- first drop.
local function hasTag(tags, want)
    for _, t in ipairs(tags or {}) do if t == want then return true end end
    return false
end

return {
    name = "Quillhide",
    description = "A foe that strikes you in melee is inflicted with Quilled.",
    onDamaged = function(ctx)
        local attacker = ctx.attacker
        if not (attacker and attacker.alive) or attacker.side == ctx.unit.side then return end
        if not hasTag(ctx.tags, "melee") then return end
        ctx.applyStatus(attacker, "status_quilled")
    end,
}
