-- Encounter blueprint. A tougher fight that only appears once the player has
-- some renown, and grows more common at higher prestige (dynamic weight).
--
-- THE WEIGHT SATURATES. It used to be `ctx.prestige` flat, against the fixed 2-3 the ordinary road
-- fights carry -- so it overtook them at prestige 3 and never stopped. Measured at prestige 20
-- (`. board-report`), a board was 3.75 elites to 1.19 combats: the elite was the ordinary fight and
-- there was nothing left for it to be tougher THAN. That also flattened the board's difficulty arc to
-- nothing, since Overworld:assignEncounterTiers reads elite as the top of the scale.
--
-- Growing more common with renown is still right; growing without bound is not a rate, it is a
-- replacement. The ceiling is reached around prestige 3 and holds for the rest of the campaign, so an
-- elite stays the exception on the road. Overworld's ELITE_SHARE caps the same thing structurally, for
-- any blueprint that gets this wrong in future.
return {
    name = "Phoenix",
    kind = "elite",
    minPrestige = 2,
    weight = function(ctx) return math.min(3, ctx.prestige or 1) end,
    -- A champion backed by an escort that grows with prestige.
    composition = function(ctx)
        local list = { "character_champion" }
        for i = 1, math.floor((ctx.prestige or 1) / 2) do list[#list + 1] = "character_bandit" end
        return list
    end,
}
