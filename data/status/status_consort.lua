-- CONSORT: the first of the company Luxuria holds each fight (data/traits/trait_the_court.lua). Half
-- again its own damage, handed in per instance at apply time (`statBonus`), and sworn to her like the rest
-- of her court: standing beside her, it takes the first blow each turn meant for her.
--
-- A RIDER ON THE CHARM, and it leaves with it. status_charm's onExpire strips this badge on every ending
-- -- a Cure, the clock, her death -- so a Consort handed back to the company never keeps the damage, or
-- the oath, for a single swing on its own side. What it wore before the oath is kept on the instance
-- and put back here.
return {
    name = "Consort",
    abbr = "Cns",
    description = "Consort: fights at half again its damage, and throws itself in front of blows meant "
        .. "for the Queen.",
    color = { 0.92, 0.36, 0.55 },
    duration = math.huge,
    hideDuration = true,
    onApply = function(ctx)
        local u, queen = ctx.unit, ctx.applier
        ctx.status.priorGuard = u.guard
        if queen then require("models.court").swear(u, queen) end
    end,
    onExpire = function(ctx)
        ctx.unit.guard = ctx.status.priorGuard
    end,
}
