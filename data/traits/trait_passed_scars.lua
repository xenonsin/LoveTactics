-- PASSED SCARS: the Orc Veteran's rule (data/items/utility/utility_old_scars.lua; 2026-11-19, the creature
-- identity pass).
--
-- When a Veteran falls, its Proven goes to the nearest orc of its side: every stack it wore (its two old scars and
-- any kill it made since) lands on that orc, through status_proven's own three-stack cap. The audit read the
-- Veteran as "the Grunt plus an opening Proven x2, which is only a stat lift"; the reviewer offered two levers,
-- refusing its first lethal blow or this, and this is the one chosen because it is the orcs' own rule (the scars
-- are visible badges before and after) and because it changes WHO DIES FIRST: a Veteran killed beside a fresh
-- Grunt hands the Grunt its scars, so you cut the Grunts down around it first, or catch the Veteran alone.
--
-- Not a reaction: a stunned Veteran's scars still pass when it falls.
return {
    name = "Passed Scars",
    grade = 0.5, -- weighed beside the rule (Grade.traitValue reads it): its Proven passed on to the nearest orc when it falls
    description = "When it falls, the nearest orc of its side takes its Proven.",
    notAReaction = true,
    onDeath = function(ctx)
        local u, combat = ctx.unit, ctx.combat
        if not (u and combat) then return end
        local Status = require("models.status")
        local stacks = Status.stacksOf(u, "status_proven")
        if stacks <= 0 then return end
        local Combat = require("models.combat")
        local heir, heirD
        for _, other in ipairs(combat.units or {}) do
            if other ~= u and other.alive and other.side == u.side and other.char and other.char.race == "orc"
                and not Combat.isOffTile(other) then
                local d = Combat.unitGap(u, other)
                if not heirD or d < heirD then heir, heirD = other, d end
            end
        end
        if not heir then return end
        ctx.applyStatus(heir, "status_proven", { applier = heir, magnitude = stacks })
        ctx.log("action", string.format("%s takes up %s's scars.", (heir.char and heir.char.name) or "An orc",
            (u.char and u.char.name) or "the Veteran"), heir)
    end,
}
