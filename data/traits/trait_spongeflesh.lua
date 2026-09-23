-- Spongeflesh: the blade sinks in, and the swing comes back as spores.
--
-- THORNS' SHAPE WITH A DIFFERENT PAYLOAD. A melee physical blow the bearer survives provokes it -- the
-- same `counter` rule trait_thorns declares, so the hover preview warns of it through the same call that
-- bites -- and what comes back is not damage but Swoon on the attacker. So the body that made you hit it
-- (the Verger's Call to Order) also takes the hitter out of the next exchange.
--
-- `chance` is the percent it fires on, read through Trait.param so one rule serves two granters: the
-- Verger's own flesh answers every blow (100), and the Spongeflesh Mantle a company can carry out of the
-- Ossuary answers a quarter of them (armor_spongeflesh_mantle). Every-time on a tank the player wears
-- would make a melee foe stand beside it doing nothing, which is not a defense, it is an off switch.
return {
    name = "Spongeflesh",
    description = "Melee attackers may be Swooned by the spores their blow shakes loose.",
    chance = 100,
    counter = { reach = "melee", requiresTag = "physical", answersReactions = true },
    onDamaged = function(ctx)
        if not ctx.mayCounter() then return end
        local attacker = ctx.attacker
        if not (attacker and attacker.alive) then return end
        local chance = ctx.param("chance", ctx.def.chance or 100)
        if chance < 100 then
            local Combat = require("models.combat")
            if Combat.roll(ctx.combat, 100) > chance then return end
        end
        ctx.applyStatus(attacker, "status_swoon", { applier = ctx.unit })
    end,
}
