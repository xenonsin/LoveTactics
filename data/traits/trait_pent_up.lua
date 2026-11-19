-- PENT UP: the Goblin Brute's rule (data/items/utility/utility_pent_up.lua).
--
-- THE BRUTE IS A BOMB WITH A FIXED CHARGE (2026-11-19, the creature identity pass). It opens every fight Primed,
-- and when it dies it bursts: fire on every tile within one, and `power` damage to every body there, both sides
-- (a bomb is not particular). Nothing it takes makes the burst bigger.
--
-- IT USED TO COUNT THE BLOWS. Each hit added Seething, the burst was 6 plus 6 a stack, and Primed came at three
-- -- Ira's trigger with its own payoff, approved 2026-09-26 on "a trigger may repeat if the payoff is unique". The
-- audit then found four bodies on Wrath's floors teaching the same sentence ("chipping it charges it: burst it or
-- leave it alone") -- the Asura's chi, this, the Cinder Slime and the Caldera King -- and the asura were kept on
-- it. So the Brute's charge is fixed and its lever moved from ORDER to POSITION: what matters now is not how many
-- times you hit it but WHERE it is when it dies. Finish it from range, or with nobody of yours beside it, or drive
-- it into its own warband and let it go off there.
local POWER = 24

return {
    name = "Pent Up",
    description = "Primed from the start. On death, deals 24 damage to everything adjacent and sets it alight.",
    notAReaction = true, -- a stunned Brute still bursts
    power = POWER,
    onCombatStart = function(ctx)
        local u = ctx.unit
        if u and u.alive then ctx.applyStatus(u, "status_primed") end
    end,
    onDeath = function(ctx)
        local u = ctx.unit
        if not u then return end
        local power = ctx.param("power", POWER)
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
