-- THE COVETOUS EYE: you hit hardest at what you would rather be.
--
--   baseline   a foe with more health than you takes heavier blows. That is the common case early --
--              the things worth envying are the things standing between you and the stair -- so the
--              piece works from the first floor with nothing else on.
--   synergy    the Envious Glass stands a copy of your STRONGEST foe on your side at the bell
--              (trait_covetous_reflection). While that copy is alive the condition is lifted and EVERY
--              foe takes the heavier blow -- you already have the thing you wanted, so nothing is
--              beneath you.
--
-- Which makes keeping the copy alive matter to the bearer rather than only to the copy, and turns
-- killing it into the other side's best play. The Glass alone never gave them that decision.
return {
    name = "Covetous Eye",
    description = "Increase damage by 5 against a foe with more health than you, or against any foe while your copy stands.",
    bonus = 5,
    onCast = function(ctx)
        local target = ctx.unitAt(ctx.tx, ctx.ty)
        if not target or not target.alive or target.side == ctx.unit.side then return end

        -- Is a body the bearer took still standing with us? `summoned` is what marks a conjured or
        -- copied unit (models/combat.lua), and the Glass's reflection is the only thing that puts one
        -- on your side without you having paid for it.
        local envied = false
        for _, u in ipairs(ctx.combat.units or {}) do
            if u.alive and u.side == ctx.unit.side and u ~= ctx.unit and u.summoned then
                envied = true
                break
            end
        end

        if not envied then
            local mine = ctx.unit.char and ctx.unit.char.stats and ctx.unit.char.stats.health
            local theirs = target.char and target.char.stats and target.char.stats.health
            if not (mine and theirs) then return end
            if (theirs.current or 0) <= (mine.current or 0) then return end
        end
        ctx.damage(target, ctx.def.bonus)
    end,
}
