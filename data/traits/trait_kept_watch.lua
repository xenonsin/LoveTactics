-- THE KEPT WATCH: it hardens every time its bearer binds somebody.
--
--   baseline   afflict a foe with anything at all and the watch takes a little armour off it, up to a
--              cap. Any party that debuffs feeds this, so it pays with nothing else equipped -- slowly,
--              and in the currency a body that intends to stand still actually wants.
--   synergy    the Forsworn Pike swears the WHOLE enemy party at the opening bell (trait_unrelieved
--              stamps `status_sworn` on every one of them at once). That is four or five applications
--              from this same bearer before anybody has taken a turn, so the horn walks into the fight
--              already at or near its ceiling -- which is exactly the fight a Sloth build wants to be
--              having: fully braced, standing still, letting the oath do the moving.
--
-- FIRED ON THE APPLIER'S SIDE. Trait.onStatusApplied fires on both ends of an application and stamps
-- `role`, so the guard below is what stops the watch rewarding its bearer for its own party being
-- cursed -- and what makes the Pike's opening salvo count, since the Pike's bearer IS the applier.
return {
    name = "Kept Watch",
    description = "Hardens each time you bind a foe, up to a limit.",
    armour = 1,
    cap = 8,
    onStatusApplied = function(ctx)
        if ctx.role ~= "applier" then return end
        local target = ctx.recipient
        if not target or not target.alive or target.side == ctx.unit.side then return end

        local held = ctx.trait.applied or 0
        if held >= ctx.def.cap then return end
        ctx.addBonus("defense", ctx.def.armour)
        ctx.trait.applied = held + ctx.def.armour
    end,
}
