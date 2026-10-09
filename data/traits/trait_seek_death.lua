-- SEEK DEATH: the Pit Locust's rule ("The Crown's Bestiary", slice C, approved 2026-10-09; carried on
-- data/items/utility/utility_seek_death.lua). "Its sting can't take a body below 1 health. Against a body already at
-- 1, each sting adds Torment."
--
-- The hold is Trait.sparesQuarry, the Lioness's seam, read by Combat.dealFlatDamage before either death path -- here
-- unconditional, since a locust has nothing to wait for. A sting on a body already at 1 lands as a blow of nothing
-- and still lands (onBlowLanded, `before`), and that is where Torment goes on. A sting that missed lays nothing.
--
-- So a swarm can never finish anybody. What it does is keep a body at the bottom of its bar and make it worse there,
-- which is what the heavy hitter it is fielded beside is for.
return {
    name = "Seek Death",
    description = "Your blows cannot take a foe below 1 health. Each blow on a foe already at 1 adds Torment.",
    sparesQuarry = function() return true end,
    onBlowLanded = function(ctx)
        local t = ctx.target
        if t and t.alive and (ctx.before or 0) <= 1 then
            ctx.applyStatus(t, "status_torment", { applier = ctx.unit })
        end
    end,
}
