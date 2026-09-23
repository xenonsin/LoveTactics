-- Digesting: a spider's venom, which is Poison that FEEDS. Spiders digest outside the body -- the bite
-- carries what dissolves the prey, and the spider drinks what it dissolved. So every tick of this deals
-- Poison's damage to the bearer and heals whoever put it there by exactly what it dealt.
--
-- Gluttony's feeding verb without a cull: Engorge eats the dead, Ravenous eats as it hits, and this
-- eats slowly, off a wound that is still open. The answer is the ordinary one for venom -- Cure it off
-- the victim, and the Larder Mother starves.
--
-- Carried by the Larder Mother's own fangs (weapon_larder_fangs, which apply it through fx.applyStatus
-- and so name her as applier) and by the Spider's Supper coating (consumable_spiders_supper, whose
-- aura status now carries the striker as applier -- Combat's coatingOpts).
--
-- THE FEEDER IS STORED ON APPLY, as status_gallows_seed stores its seeder: Status.apply hands the
-- applier to onApply and nowhere else. A refresh keeps the first feeder. One that has since died is
-- simply not fed; the venom still works.
return {
    name = "Digesting",
    abbr = "Dig",
    description = "Takes toxic damage as time passes, and whoever inflicted it recovers that much health.",
    color = { 0.62, 0.66, 0.30 }, -- badge tint (venom, yellowed)
    fx = { field = true },
    duration = 25, -- Poison's own clock
    magnitude = 3,
    debuff = true,
    lingers = true,
    onApply = function(ctx)
        if ctx.status.feeder == nil then ctx.status.feeder = ctx.applier end
    end,
    onTick = function(ctx)
        local n = ctx.accrue(ctx.magnitude)
        if n <= 0 then return end
        local dealt = ctx.damage(ctx.unit, n, { "poison" }) or 0
        local feeder = ctx.status.feeder
        if dealt > 0 and feeder and feeder.alive and feeder ~= ctx.unit then
            ctx.heal(feeder, dealt)
        end
    end,
}
