-- THE RUN: the bull's charge (models/labyrinth.lua; "The Minotaur", 2026-09-26/27). Worn by the Minotaur on its
-- Bull's Brow, and by whoever takes the brow off it.
--
-- A bearer that walks two or more tiles in an unbroken straight line and then lands a hand-to-hand blow drives
-- the body it struck back one tile for every two it ran, up to 3 -- and with its head down (status_head_down),
-- one tile per tile. The straight stretch is the last one walked this turn, counted by Combat.stepMove onto
-- the turn record, so a run that turned a corner counts only from the corner.
--
-- NOT Skirmisher's Momentum, which pays a blow after moving in DAMAGE. This pays in DISTANCE, and a shove that
-- is stopped short by a wall, a body or fire hurts as every stopped shove does (Combat.knockback). Once a turn:
-- the first blow spends the run, so an axe's arc drives back the one body it was aimed at and not all three.
local Labyrinth = require("models.labyrinth")

return {
    name = "The Run",
    description = "Move 2+ tiles in a straight line, then strike: the foe is driven back 1 tile for every 2 run, up to 3.",
    theRun = true,
    onCast = function(ctx)
        local combat, unit = ctx.combat, ctx.unit
        local turn = combat and combat.turn
        if not (turn and turn.unit == unit and (turn.runLine or 0) >= 2) then return end
        local ab = ctx.ability
        if not (ab and (ab.range or 0) <= 1 and (ctx.damageDealt or 0) > 0) then return end
        local tt = ctx.tx and ctx.unitAt(ctx.tx, ctx.ty)
        local distance = Labyrinth.runDistance(unit, turn.runLine)
        turn.runLine = 0
        if tt and tt ~= unit and tt.alive and distance > 0 then ctx.knockback(tt, distance) end
    end,
}
