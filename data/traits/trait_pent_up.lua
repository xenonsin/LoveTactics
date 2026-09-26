-- PENT UP: the Goblin Brute's rule (data/items/utility/utility_pent_up.lua).
--
-- Each hit taken adds a stack of Seething, counted the way Boil Over counts it (`count`, magnitude = count x
-- step). It never erupts while the Brute stands -- that is the Caldera King's payoff, not this one. It bursts
-- when the Brute DIES: fire on every tile within one, and `perStack` damage per stack to every body there,
-- both sides (a bomb is not particular). At `primeAt` stacks it wears Primed, the badge that says so.
--
-- So chipping at it makes it both stronger and a bomb: kill it in one blow, from range, or while it stands
-- among its own.
local STEP = 2

return {
    name = "Pent Up",
    description = "Each hit taken adds Seething. On death, deals 6 plus 6 per stack to everything adjacent and sets it alight.",
    notAReaction = true, -- a stunned Brute still takes it in
    perStack = 6,
    base = 6,
    primeAt = 3,
    onDamaged = function(ctx)
        local u = ctx.unit
        if not (u and u.alive) or (ctx.amount or 0) <= 0 then return end
        local Status = require("models.status")
        if not Status.has(u, "status_seething") then ctx.applyStatus(u, "status_seething", { magnitude = 0 }) end
        local s = Status.get(u, "status_seething")
        if not s then return end
        s.count = (s.count or math.floor((s.magnitude or 0) / STEP)) + 1
        s.magnitude = s.count * STEP
        if s.count >= ctx.param("primeAt", 3) and not Status.has(u, "status_primed") then
            ctx.applyStatus(u, "status_primed")
        end
    end,
    onDeath = function(ctx)
        local u = ctx.unit
        if not u then return end
        local s = require("models.status").get(u, "status_seething")
        local stacks = (s and s.count) or 0
        if stacks <= 0 then return end
        local power = ctx.param("base", 6) + ctx.param("perStack", 6) * stacks
        ctx.log("action", string.format("%s bursts!", (u.char and u.char.name) or "It"), u)
        ctx.burst(u.x, u.y, { "fire" })
        for dy = -1, 1 do
            for dx = -1, 1 do
                if not (dx == 0 and dy == 0) then ctx.placeHazard(u.x + dx, u.y + dy, "hazard_fire", { side = false }) end
            end
        end
        for _, other in ipairs(ctx.unitsNear(u.x, u.y, 1)) do
            if other ~= u and other.alive then ctx.damage(other, power, { "fire", "magical" }) end
        end
    end,
}
