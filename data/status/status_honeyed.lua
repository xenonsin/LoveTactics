-- Honeyed: what the Alraune's sweet ground does to whoever stands in it, and the Lust circle's fourth
-- verb -- WANTING COSTS -- turned inside out. Everywhere else on this stratum the reaching is billed; here
-- the ground pays you for being there, and the bill is the turns.
--
-- TWO BEATS, ON PURPOSE. It mends the moment a body steps onto the honey (onApply -- a zone re-lays it
-- on entry, so every arrival is a meal), and it puts a body to sleep at the END of that body's own turn
-- if it is still standing there. The gap between the two is the whole decision: a company that steps
-- in, drinks, and steps off again has been healed for free. What makes that impossible is somebody else
-- -- the Mandrake's Taproot, which holds a body where it stands -- and that is the Alraune line's trap
-- stated as two files.
--
-- ZONE-BOUND, like every status a ground grants (models/hazard.lua stamps the source), so it lasts
-- exactly as long as the body stands on the honey and ends the beat it steps off. The SLEEP it hands out
-- is not zone-bound: it is applied by this status, not by the ground, so it outlives the step off --
-- and breaks on the first blow, as every sleep does (data/status/status_sleep.lua).
return {
    name = "Honeyed",
    abbr = "Hny",
    description = "Healed on arrival. Falls asleep at the end of its turn if it is still here.",
    color = { 0.890, 0.741, 0.353 }, -- badge tint (honey)
    duration = 9999,              -- zone-bound: the ground decides, never the clock
    magnitude = 8,                -- the mouthful: health restored on every arrival
    onApply = function(ctx)
        local amount = ctx.magnitude or 0
        if amount > 0 then ctx.heal(ctx.unit, amount) end
    end,
    onTurnEnd = function(ctx)
        ctx.log("status", string.format("%s sinks into the sweetness.",
            (ctx.unit.char and ctx.unit.char.name) or "Unit"))
        ctx.applyStatus(ctx.unit, "status_sleep")
    end,
}
