-- FULL HORN OUT: the Horned Twin with her sister fallen (trait_the_horned_sister). Approved 2026-09-27 ("The Oni of
-- Wrath", round 2, the Twins' elite): "her morning star sweeps every tile within 3 of her each turn, and she heals
-- 20% a turn."
--
-- The sweep is her own cast (ability_the_sweep, usable only under this status); the heal is here. It lasts the
-- fight, and only a snapped horn ends it (trait_the_horn takes this off with the ordinary Horn Out).
local HEAL = 0.20

return {
    name = "Full Horn Out",
    abbr = "Horn!",
    description = "Horn all the way out: increases damage by 5 and speed by 1, and heals 20% of health each turn.",
    color = { 0.860, 0.140, 0.100 }, -- badge tint (a brighter oni red)
    duration = math.huge,
    hideDuration = true,
    statBonus = { damage = 5, speed = 1 },
    healShare = HEAL,
    onTurnStart = function(ctx)
        local u = ctx.unit
        if not (u and u.alive) then return end
        local Combat = require("models.combat")
        ctx.heal(u, math.max(1, math.floor(Combat.unreservedMax(u.char, "health") * HEAL + 0.5)))
    end,
}
