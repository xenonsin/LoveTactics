-- COALESCE: the wood's slimes eat each other. Gluttony's slime mechanic -- every circle's slime line
-- carries one rule of its own, and this circle's is the circle's own verb: it EATS.
--
-- A moss slime beside another moss slime swallows it whole and takes all of its remaining health into
-- itself, ceiling included (Combat.devour's `absorb`). Two wounded slimes become one healthy, bigger one;
-- the Moss King eats his own escort to heal past his cap, and what he splits into when he falls goes on
-- eating each other. So the board asks one question the fen does not: KEEP THEM APART. A slime killed
-- alone is a slime gone; one left standing beside its kin is a slime that comes back fatter.
--
-- WHY THE GORGED, borrowed from Devour for Devour's own reason: a heal forecasts as nothing on a body at
-- full health, and the swelling is granted on the live path only (the forecast must never grow a body),
-- so without a visible gain the planner would read a full-health slime eating its kin as doing nothing.
-- A slime that has just eaten also hits harder for a couple of turns, which is true and legible.
--
-- Its whole action: eating is instead of attacking, which is the price -- and the player's window.
local EATS = { character_moss_slime = true }

-- The adjacent kin to swallow: the most wounded first (the least lost to the kill it spares you),
-- read-only so it is safe under the forecast.
local function kinNear(combat, unit)
    local Combat = require("models.combat")
    local best
    for _, u in ipairs((combat and combat.units) or {}) do
        if u ~= unit and u.alive and u.side == unit.side and u.char and EATS[u.char.id]
            and not u.summoned and Combat.cellGap(u.x, u.y, unit) == 1 then
            local hp = u.char.stats.health.current
            if not best or hp < best.char.stats.health.current then best = u end
        end
    end
    return best
end

return {
    name = "Coalesce",
    description = "Swallows an adjacent moss slime, taking all of its health into itself.",
    flavor = "There were two of them. Then there was more of one.",
    sprite = "assets/items/ability_coalesce.png",
    type = "ability",
    class = "creature",
    tags = { "natural" },
    noSteal = true,
    activeAbility = {
        target = "self",
        range = 0,
        speed = 4,
        support = true,
        ai = { priority = "high", act = "support", label = "its kin is beside it",
               whenFn = function(ctx)
                   return kinNear(ctx.combat, ctx.unit) ~= nil
               end },
        effect = function(fx)
            local body = fx.combat and fx.user and kinNear(fx.combat, fx.user)
            if not body then return end
            if not fx.devour(body, { absorb = true }) then return end
            fx.applyStatus(fx.user, "status_gorged")
        end,
    },
}
