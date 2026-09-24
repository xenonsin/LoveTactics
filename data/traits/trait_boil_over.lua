-- BOIL OVER: Wrath's slime rule. Every hit that lands adds a stack of Seething (+2 Damage each); at
-- `eruptAt` stacks it ERUPTS -- every body next to it takes a blast in the element the slime has taken
-- into itself (trait_adaptive's Immune: <element>), or fire while it has taken none -- and the count
-- starts again. So hitting it charges it: finish it in a burst, or step off before it blows.
--
-- The count lives on the status (`count`), and a piece that arrives already Seething (the Caldera King's,
-- via trait_split's `pieceStatus`) reads its count back off the magnitude.
local function adaptedElement(unit)
    local Combat = require("models.combat")
    local Status = require("models.status")
    for _, e in ipairs(Combat.ELEMENTS) do
        if Status.has(unit, "status_immune_" .. e) then return e end
    end
    return "fire"
end

return {
    name = "Boil Over",
    description = "Each hit it takes adds Seething; at 5 stacks it erupts, blasting everything next to it.",
    step = 2,
    eruptAt = 5,
    blast = 14,
    onDamaged = function(ctx)
        local u = ctx.unit
        if not (u and u.alive) or (ctx.amount or 0) <= 0 then return end
        local Status = require("models.status")
        local step = ctx.param("step", 2)
        if not Status.has(u, "status_seething") then ctx.applyStatus(u, "status_seething", { magnitude = 0 }) end
        local s = Status.get(u, "status_seething")
        if not s then return end
        s.count = (s.count or math.floor((s.magnitude or 0) / step)) + 1
        s.magnitude = s.count * step
        if s.count < ctx.param("eruptAt", 5) then return end
        local element = adaptedElement(u)
        local power = ctx.param("blast", 14) + s.magnitude
        s.count, s.magnitude = 0, 0
        ctx.clearStatus(u, "status_seething")
        ctx.log("action", string.format("%s boils over in %s!",
            (u.char and u.char.name) or "It", element), u)
        for _, other in ipairs(ctx.unitsNear(u.x, u.y, 1)) do
            if other ~= u and other.alive then ctx.damage(other, power, { element, "magical" }) end
        end
    end,
}
