-- IN MOLTEN GOLD: standing in her melted hoard (data/hazards/hazard_molten_gold.lua). Round 3, 2026-09-25:
-- "Molten Gold gilds whoever ends a turn in it" -- and the status it gilds with is the dwarves' own Gilded
-- (settled the same day: one word, one mechanic).
--
-- ZONE-BOUND, which is what makes "ends a turn in it" true: the zone grants this on entry and Hazard.reap
-- lifts it the moment the body is no longer on molten ground, so onTurnEnd only ever fires for a body that
-- finished its turn standing in the gold.
return {
    name = "In Molten Gold",
    abbr = "Molt",
    description = "Standing in molten gold: ending a turn here leaves it Gilded.",
    color = { 0.930, 0.560, 0.150 }, -- badge tint (poured gold)
    duration = math.huge,
    hideDuration = true,
    debuff = true,
    onTurnEnd = function(ctx)
        if not (ctx.combat and ctx.unit and ctx.unit.alive) then return end
        require("models.status").apply(ctx.combat, ctx.unit, "status_gilded", {})
        ctx.log("action", string.format("The gold hardens on %s.",
            (ctx.unit.char and ctx.unit.char.name) or "it"), ctx.unit)
    end,
}
