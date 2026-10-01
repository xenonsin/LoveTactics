-- THE PROUD FALL: the Tower-Giant's rule, carried on its organ beside Ambition (data/items/utility/
-- utility_the_unfinished_tower.lua; "Pride's Bestiary", 2026-09-30).
--
-- When it falls it CRASHES onto every tile within 1 + floor(Ambition / 3) of it -- the square ring
-- Combat.unitsNear measures -- for 6 impact damage per stack of Ambition, mitigated as any blow is, and on
-- every body there whichever side it stands on. Nothing at all if it falls before its first turn's end.
--
-- THE SCALE, stated (PrideElites.crashOf): after 3 of its turns it reaches 2 tiles for 18, after 6 it reaches
-- 3 for 36, after 9 it reaches 4 for 54. The proud fall hardest -- so kill it early, or clear the ground before
-- the last blow, and the decision is legible on its badge's count the whole fight.
--
-- On onDeath (the blow that kills fires no onDamaged), with the body still on its tile, as Volatile bursts.
local PrideElites = require("models.pride_elites")

return {
    name = "The Proud Fall",
    description = "When it falls, it crashes on everything within 1 + Ambition/3 tiles for 6 damage per stack of Ambition.",
    onDeath = function(ctx)
        local unit = ctx.unit
        if not unit then return end
        local Status = require("models.status")
        local radius, blow = PrideElites.crashOf(Status.stacksOf(unit, PrideElites.AMBITION))
        if blow <= 0 then return end
        ctx.burst(unit.x, unit.y, { "impact" })
        ctx.log("action", string.format("%s falls, and the tower falls with it.",
            (unit.char and unit.char.name) or "The Tower-Giant"), unit)
        for _, u in ipairs(ctx.unitsNear(unit.x, unit.y, radius)) do
            if u ~= unit and u.alive then ctx.damage(u, blow, { "impact", "physical" }) end
        end
    end,
}
