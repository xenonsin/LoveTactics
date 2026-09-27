-- HORN OUT: an oni with its horn out (data/traits/trait_the_horn.lua). Reviewed 2026-09-26/27 ("The Oni of
-- Wrath"), after Re:Zero's premise that the horn is where an oni's power lives and that restraint goes when it
-- comes out.
--
-- It lasts the fight. What ends it is the horn itself: a critical hit snaps it (status_horn_snapped), and the
-- snap takes this off. It heals a tenth of the bearer's health at the top of each of its turns, and the AI sends
-- the bearer at whoever it is avenging (`unit.hornTarget`, AI.preempt) when it can reach them.
--
-- Not a debuff, so no Cure lifts it: it is not something done TO the oni, it is what the oni is now.
local HEAL = 0.10

return {
    name = "Horn Out",
    abbr = "Horn",
    description = "Horn out: increases damage by 3 and speed by 1, and heals 10% of health each turn.",
    color = { 0.760, 0.220, 0.160 }, -- badge tint (oni red)
    duration = math.huge,
    hideDuration = true,
    statBonus = { damage = 3, speed = 1 },
    healShare = HEAL, -- read by tests/oni_line_spec.lua
    onTurnStart = function(ctx)
        local u = ctx.unit
        if not (u and u.alive) then return end
        local Combat = require("models.combat")
        local amount = math.max(1, math.floor(Combat.unreservedMax(u.char, "health") * HEAL + 0.5))
        ctx.heal(u, amount)
    end,
}
