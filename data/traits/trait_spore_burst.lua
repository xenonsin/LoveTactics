-- Spore Burst: a Puffer that is cut down goes off where it stands.
--
-- trait_volatile's rule with a different payload. The Bomblet carries the same pair -- a death that
-- bursts, and a deliberate cast (ability_self_destruct, here weapon_pop) that bursts on purpose -- and
-- the two never double up, because the cast spends its bearer through fx.expendSelf, which is a
-- dismissal and fires no death hook. This file is the half that answers a bearer somebody ELSE killed.
--
-- POISON AND SWOON, BOTH SIDES. The blast is mitigated `poison` damage and a Swoon on everything within
-- `radius`, the Puffer's own folk included -- so a company that shoots one standing in its own crowd has
-- used the spores on the mushrooms, and one that lets it reach the line has swooned its front.
return {
    name = "Spore Burst",
    description = "On death, bursts: poison damage and Swoon on everything beside it.",
    magnitude = 6, -- blast power before mitigation: the spores are the weapon, the sting an afterthought
    radius = 1,
    onDeath = function(ctx)
        ctx.burst(ctx.unit.x, ctx.unit.y, { "poison" })
        for _, u in ipairs(ctx.unitsNear(ctx.unit.x, ctx.unit.y, ctx.def.radius or 1)) do
            if u ~= ctx.unit and u.alive then
                ctx.damage(u, ctx.def.magnitude or 0, { "poison", "magical" })
                if u.alive then ctx.applyStatus(u, "status_swoon", { applier = ctx.unit }) end
            end
        end
    end,
}
