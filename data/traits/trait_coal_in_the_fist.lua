-- COAL IN THE FIST: the Blaze's blows kindle the ground (models/storm.lua; "Fire, Lightning, and Dirty Thunder",
-- 2026-09-27). A WEAPON blow that lands sets the struck tile alight -- and a fire laid under a standing body burns it
-- at once (Hazard.place). Not the Fire Stone, which Burns the body: this lights the GROUND, so it lingers after the
-- body walks off it, and a Wildfire beside it spreads it.
return {
    name = "Coal in the Fist",
    description = "Your weapon blows set the struck tile alight.",
    onCast = function(ctx)
        -- ctx.item here is the CAST item (the event shadows the granting one), which is the one Storm.kindle asks.
        require("models.storm").kindle(ctx.combat, ctx.unit, ctx)
    end,
}
