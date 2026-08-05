-- The Sealed Reliquary's mechanism: it puts the ward up when the battle opens, and puts it up again
-- some time after it has been spent.
--
-- Two hooks doing one job, and neither of them is the ward itself -- the refusal lives entirely in
-- Status.castWardOn and resolveCast. All this file decides is WHEN there is a seal to refuse with:
--
--   * onCombatStart -- the relic is sealed before the first turn. A ward that had to be switched on
--     would just be an ability, and the whole point of a passive one is that the enemy must plan
--     around it before they know whether it is there.
--   * onAnyCast -- the reseal. Checked on somebody else's cast rather than on a timer of its own,
--     because that is the only regular beat a trait can hear (there is deliberately no per-tick trait
--     hook -- see models/trait.lua). The cooldown is what actually paces it; the hook is just the
--     thing that keeps looking.
--
-- The cooldown is long on purpose: a refused spell is a whole enemy turn deleted, and two of those a
-- battle is already the strongest defensive item on the shelf. It starts when the seal is SPENT rather
-- than when it is set, which the check below gets for free -- the status is gone, so the reseal is
-- attempted, and the cooldown set on the first attempt is the one that gates it.
--
-- Keyed on this trait's own id, like every other cooldown: Combat.itemCooldown looks the bearer's
-- timers up by trait id to find the grid slot they belong to, so a bespoke key would tick down
-- correctly and still leave the Reliquary's slot reading as ready the whole time it was spent.
return {
    name = "Sealed Reliquary",
    description = "Holds a seal against one aimed spell, and renews it a while after it is spent.",
    cooldown = 45, -- ticks between seals: ~9 turns, so roughly two a battle
    onCombatStart = function(ctx)
        ctx.applyStatus(ctx.unit, "status_sealed_ward")
    end,
    onAnyCast = function(ctx)
        local Status = require("models.status")
        -- Already sealed: nothing to do, and nothing to charge for. Checked first so a battle full of
        -- casting never puts the reseal on cooldown while the ward is standing untouched.
        if Status.castWardOn(ctx.unit) then return end
        if ctx.onCooldown("trait_sealed_reliquary") then return end
        ctx.setCooldown("trait_sealed_reliquary", ctx.def.cooldown or 45)
        ctx.applyStatus(ctx.unit, "status_sealed_ward")
        ctx.log("status", string.format("%s's reliquary locks itself again.",
            ctx.unit.char and ctx.unit.char.name or "Unit"), ctx.unit)
    end,
}
