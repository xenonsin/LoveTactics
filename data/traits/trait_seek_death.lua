-- SEEK DEATH: the Pit Locust's rule ("The Crown's Bestiary", slice C, approved 2026-10-09; carried on
-- data/items/utility/utility_seek_death.lua). "Its sting can't take a body below 1 health."
--
-- The hold is Trait.sparesQuarry, the Lioness's seam, read by Combat.dealFlatDamage before either death path -- here
-- unconditional, since a locust has nothing to wait for. So a swarm can never finish anybody.
--
-- THE TORMENT MOVED OFF THE HEALTH BAR (the creature identity pass, 2026-11-19). It used to land on a body already at
-- 1, and the audit found three bodies on the bottom floors all keyed on your wounded: the Lioness holds prey at 1,
-- the Reaper Downs a body under its line, and the locust Tormented a body at 1. The locust was moved, because the
-- other two ARE that rule and the locust is a swarm. A sting now adds Torment when ANOTHER locust (any body carrying
-- this rule) stands beside the foe it stings -- so the lever is where you stand: never let two of them reach the same
-- body. Read on onBlowLanded, so a sting that missed lays nothing.
local function swarmedBeside(combat, me, target)
    local Combat = require("models.combat")
    local Trait = require("models.trait")
    for _, u in ipairs((combat and combat.units) or {}) do
        if u ~= me and u.alive and u.side == me.side and Trait.flag(u, "swarms")
            and Combat.unitGap(u, target) == 1 then
            return true
        end
    end
    return false
end

return {
    name = "Seek Death",
    description = "Your blows cannot take a foe below 1 health. A blow on a foe beside another of the swarm adds Torment.",
    swarms = true,
    sparesQuarry = function() return true end,
    onBlowLanded = function(ctx)
        local t = ctx.target
        if t and t.alive and swarmedBeside(ctx.combat, ctx.unit, t) then
            ctx.applyStatus(t, "status_torment", { applier = ctx.unit })
        end
    end,
}
