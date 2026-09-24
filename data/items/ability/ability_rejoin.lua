-- REJOIN: a moss sloughling gives itself back to the body it came from (Combat.rejoin).
--
-- The player's half of Coalesce (ability_coalesce). The wood's slimes eat each other; a company's
-- sloughlings are pieces of one of its own, so they do not eat -- they go home. The maker is healed by
-- whatever health the piece still has, never past their ceiling, and the piece is gone.
--
-- Cast by the piece, standing beside its maker, as its whole action. The planner takes it whenever the
-- maker is hurt, which is the only time it is worth a turn -- a piece beside a whole body is more use
-- fighting than folded back in.
local function home(unit)
    local maker = unit and unit.summoner
    if not (maker and maker.alive) then return nil end
    return maker
end

return {
    name = "Rejoin",
    description = "Beside the body it came from: give itself back, healing them by its remaining health.",
    flavor = "It was only ever out on loan.",
    sprite = "assets/items/ability_rejoin.png",
    type = "ability",
    class = "creature",
    tags = { "natural" },
    noSteal = true,
    activeAbility = {
        target = "self",
        range = 0,
        speed = 3,
        support = true,
        ai = { priority = "high", act = "support", label = "it is home, and home is hurt",
               whenFn = function(ctx)
                   local Combat = require("models.combat")
                   local maker = home(ctx.unit)
                   if not maker or Combat.cellGap(ctx.unit.x, ctx.unit.y, maker) ~= 1 then return false end
                   local hp = maker.char.stats.health
                   return hp.current < hp.max
               end },
        effect = function(fx)
            if not home(fx.user) then return end
            fx.rejoin()
        end,
    },
}
