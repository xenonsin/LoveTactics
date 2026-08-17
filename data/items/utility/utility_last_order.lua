-- Marek's bound relic (Warlord). He never swings first -- he tells eight other people where to swing,
-- and this is him saying it.
--
-- NOT A NINTH BANNER. The Warlord shelf already sells five (Rally, Muster and Pincer Banner, The
-- Crimson Standard, the Rally Coat), and a relic that planted a sixth would be the shelf's own idea
-- with a bigger number on it. This one SPENDS what those five built: every ally standing in ground he
-- has planted acts immediately, out of order. Nothing is buffed and nothing new is laid. The company
-- simply moves at once, because he said so.
--
-- THE CENSUS IS THE BUILD. It counts allies standing in his ground, so the banners are both what opens
-- the relic and what decides its worth -- more standards planted is more of the line covered, and a
-- warlord who has laid nothing has nobody to give an order to.
--
-- Extra turns are granted through Combat.grantExtraAction, the seam a Haste-adjacent grant already
-- uses, so the timeline and the turn strip stay the one authority on who acts next.
local Hazard = require("models.hazard")

-- Is `u` standing in ground `owner` laid? The census clause and the payoff both call this, so the gate
-- and the effect can never disagree about who is covered.
local function inOwnGround(u, owner, combat)
    if not (combat and u and u.x and u.y) then return false end
    local ground = Hazard.at(combat, u.x, u.y)
    return ground ~= nil and owner ~= nil and ground.side == owner.side
end

return {
    name = "The Last Order",
    description = "Every ally standing in ground you have planted takes a turn at once.",
    flavor = "The line does not need telling twice. It needs telling once, at the right moment.",
    sprite = "assets/items/sig_last_order.png",
    type = "utility",
    tags = { "signature", "banner" },
    class = "fighter",
    discipline = "warlord",
    bound = true,
    activeAbility = {
        target = "self",
        range = 0,
        speed = 6,
        cost = { stat = "stamina", amount = 12 },
        description = "Every ally in ground you planted takes a turn at once.",
        unlock = {
            field = { of = "unit", side = "ally", count = 3,
                      test = function(u, unit, combat) return inOwnGround(u, unit, combat) end },
            text = "3 allies in ground you planted",
        },
        effect = function(fx)
            for _, u in ipairs((fx.combat and fx.combat.units) or {}) do
                if u.alive and u ~= fx.user and u.side == fx.user.side
                    and inOwnGround(u, fx.user, fx.combat) then
                    fx.grantExtraAction(1, u)
                end
            end
        end,
    },
}
