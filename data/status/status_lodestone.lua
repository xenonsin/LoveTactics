-- LODESTONE: the Gold Golem's trophy turned on the company's side. At the start of the bearer's turn every
-- foe within 3 is dragged one tile toward it -- Gold Calls to Gold, with bodies where the heaps were, so it
-- works on every floor and not only in Greed's cave (round 2's note: "needs to be useful everywhere").
-- A body that cannot be moved (Root, Stout, the Unheld) stays put. Laid for the fight by trait_lodestone.
return {
    name = "Lodestone",
    abbr = "Lode",
    description = "At the start of your turn, every foe within 3 is dragged one tile toward you.",
    color = { 0.500, 0.520, 0.600 }, -- badge tint (magnetite)
    duration = math.huge,
    hideDuration = true,
    hideLog = true,
    onTurnStart = function(ctx)
        local combat, unit = ctx.combat, ctx.unit
        if not (combat and unit and unit.alive) then return end
        local Combat = require("models.combat")
        local Status = require("models.status")
        for _, foe in ipairs(Combat.unitsNear(combat, unit.x, unit.y, 3)) do
            if foe.alive and foe.side ~= unit.side and Combat.unitGap(unit, foe) > 1
                and (foe.w or 1) == 1 and (foe.h or 1) == 1 and not Status.blocksForcedMove(foe) then
                local dx, dy = unit.x - foe.x, unit.y - foe.y
                local nx = foe.x + (dx > 0 and 1 or dx < 0 and -1 or 0)
                local ny = foe.y + (dy > 0 and 1 or dy < 0 and -1 or 0)
                if Combat.footprintFree(combat, 1, 1, nx, ny, foe) then
                    Combat.teleportUnit(combat, foe, nx, ny, { glide = true })
                end
            end
        end
        ctx.log("action", string.format("%s's lodestone drags the foes near it closer.",
            (unit.char and unit.char.name) or "It"), unit)
    end,
}
