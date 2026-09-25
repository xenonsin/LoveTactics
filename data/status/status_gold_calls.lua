-- GOLD CALLS TO GOLD: the Gold Golem's signature (round 2, picked over Hoard Quake). At the start of its
-- turn every coin heap within 4 slides one tile toward it, and a heap that reaches it is eaten
-- (models/golem.lua). Laid for the whole fight by trait_gold_calls; the badge is the tell.
return {
    name = "Gold Calls to Gold",
    abbr = "Calls",
    description = "At the start of its turn, every coin heap within 4 slides one tile toward it.",
    color = { 0.886, 0.700, 0.250 },
    duration = math.huge,
    hideDuration = true,
    hideLog = true,
    onTurnStart = function(ctx)
        if not (ctx.combat and ctx.unit and ctx.unit.alive) then return end
        require("models.golem").callGold(ctx.combat, ctx.unit)
    end,
}
