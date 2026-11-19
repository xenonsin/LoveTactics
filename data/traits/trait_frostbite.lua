-- FROSTBITE: the Frost Slime's rule (the creature identity pass, 2026-11-19). It replaced Numb, which stacked a
-- cost rise on whoever the slime touched -- a tax nobody could see until the bill came.
--
-- This one is the other way round, and it is on the slime: a blow that lands on it from an ADJACENT foe Freezes
-- the striker (status_freeze -- delayed, and brittle to impact and fire). A slime is proof against steel, so the
-- only blows that land are elemental ones, and the rule says where to throw them from: at range. A branded blade
-- still works, and still costs the hand that swung it a turn.
--
-- onDamaged, so a voided blow freezes nobody (nothing got through to the cold) and a blow that KILLS it freezes
-- nobody either -- finishing one in melee is safe.
return {
    name = "Frostbite",
    grade = 1.5, -- weighed beside the rule (Grade.traitValue reads it): Frozen on whoever lands a blow on it from beside it
    description = "A foe beside it whose blow lands on it is Frozen.",
    onDamaged = function(ctx)
        local u, a = ctx.unit, ctx.attacker
        if not (u and u.alive and a and a.alive) or a.side == u.side then return end
        if (ctx.amount or 0) <= 0 then return end
        if require("models.combat").unitGap(u, a) > 1 then return end
        ctx.applyStatus(a, "status_freeze", { applier = u })
        ctx.log("status", string.format("%s touches %s and freezes to it.",
            (a.char and a.char.name) or "It", (u.char and u.char.name) or "it"), { a, u })
    end,
}
