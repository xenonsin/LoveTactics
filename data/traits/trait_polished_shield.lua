-- POLISHED SHIELD (armor_polished_shield): a melee attacker that draws blood is Rattled. Built as Spiteful Ichor is
-- -- free, uncooled, no swing -- because a mirror holds no guard to wear down; what keeps it honest is that Rattled
-- is a nudge (-3 skill, -1 speed), not a wound.
return {
    name = "Polished Shield",
    description = "A foe that strikes you in melee is Rattled.",
    duration = 8,
    counter = { reach = "melee", requiresTag = "physical", answersReactions = true,
                applies = "status_rattled" },
    onDamaged = function(ctx)
        if not ctx.mayCounter() then return end
        ctx.applyStatus(ctx.attacker, "status_rattled", { applier = ctx.unit, duration = ctx.param("duration", 8) })
        ctx.log("action", string.format("%s sees itself in %s's shield.",
            (ctx.attacker.char and ctx.attacker.char.name) or "The attacker",
            (ctx.unit.char and ctx.unit.char.name) or "the bearer"))
    end,
}
