-- WHICH ONE IS REAL: the Mirage's rule, on its organ (data/items/utility/utility_which_one_is_real.lua). Reviewed
-- 2026-10-01..03 ("Envy's Bestiary", round 1).
--
-- At the bell the real one puts three illusions of itself on the ground beside it (Summon.copy, `fragile`): any
-- blow fells one, and their own blows land nothing (Combat.dealFlatDamage). Struck and still standing, the real
-- one trades places with an illusion -- once a round, the latch re-armed at the end of its own turn. Illusions
-- weigh nothing, so the sand does not take them (Status.isImmune). The illusions carry this organ too, as copies
-- carry everything; every hook here asks the body whether it is the real one first.
--
-- `notAReaction`: the shimmer is what the thing is, not a reflex, so a stunned Mirage still shifts.
return {
    name = "Which One Is Real",
    description = "Fights beside three illusions of itself. Struck, it trades places with one, once a round.",
    notAReaction = true,
    onCombatStart = function(ctx)
        local u = ctx.unit
        if u and u.alive and not u.illusory then require("models.envy_oneoffs").raiseMirage(ctx.combat, u) end
    end,
    onDamaged = function(ctx)
        local u = ctx.unit
        if u and u.alive and not u.illusory then require("models.envy_oneoffs").mirageShift(ctx.combat, u) end
    end,
    onTurnEnd = function(ctx)
        if ctx.unit then ctx.unit.mirageShifted = nil end
    end,
}
