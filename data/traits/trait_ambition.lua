-- AMBITION: one stack of status_ambition at the end of each of the bearer's turns ("Pride's Bestiary",
-- 2026-09-30). The Tower-Giant carries it on its organ, beside the fall that consumes the count
-- (trait_the_proud_fall); the Babel Maul carries it on the haft, and its next hit consumes the count for
-- +3 damage a stack (data/items/weapon/weapon_babel_maul.lua).
--
-- At the turn's END, because traits have no turn-start hook -- and so a Giant felled before its first turn
-- has ambitions it never got to keep, and falls on nobody.
return {
    name = "Ambition",
    description = "Gain a stack of Ambition at the end of each of your turns.",
    onTurnEnd = function(ctx)
        local unit = ctx.unit
        if unit and unit.alive then ctx.applyStatus(unit, "status_ambition", { magnitude = 1, applier = unit }) end
    end,
}
