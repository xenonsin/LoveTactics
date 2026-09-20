-- TETHERED: the bearer's wounds are not only theirs (data/curses/curse_the_tether.lua).
--
-- A share of every blow that lands on the bearer is dealt again to the nearest living ally. The only
-- curse effect in the game that is about WHERE FOUR BODIES STAND rather than about a number on a sheet,
-- and the reason it had to be a trait: `bonus` and `rules` can say what a body is worth, and neither can
-- say "and the person next to you pays too".
--
-- A SHARE, NEVER A FLAT FIGURE, so it scales with the blow instead of with the floor. A scratch splashes
-- a scratch and the boss's opener is what makes the player move -- which is the correct distribution of
-- attention for a rule that is supposed to change positioning rather than arithmetic.
--
-- NEAREST BY THE BOARD'S OWN MEASURE, walking combat.units rather than a radius helper, because the
-- splash has to find SOMEBODY however far the company has spread. A lone survivor splashes nothing and
-- the hex quietly stops mattering -- which is right: there is nobody left to tether to.
--
-- Fires on onDamaged, so it never triggers on a blow that felled the bearer (models/trait.lua: "the
-- bearer was hit and SURVIVED"). A body going down does not take its neighbour with it.
return {
    name = "Tethered",
    description = "A quarter of every wound the bearer takes is dealt to the nearest ally.",
    share = 0.25,
    onDamaged = function(ctx)
        local amount = math.floor((ctx.amount or 0) * (ctx.def.share or 0.25))
        if amount <= 0 then return end
        local unit, combat = ctx.unit, ctx.combat
        if not (unit and combat) then return end

        -- The nearest living ally that is not the bearer. Ties go to the earlier unit in the list, so a
        -- replayed fight splashes onto the same body twice.
        local best, bestGap
        for _, other in ipairs(combat.units or {}) do
            if other ~= unit and other.alive and other.side == unit.side then
                local gap = math.abs((other.x or 0) - (unit.x or 0))
                    + math.abs((other.y or 0) - (unit.y or 0))
                if not bestGap or gap < bestGap then best, bestGap = other, gap end
            end
        end
        if not best then return end
        ctx.damage(best, amount, { "dark" })
    end,
}
