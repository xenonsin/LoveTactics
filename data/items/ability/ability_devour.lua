-- DEVOUR: Gula eats a body beside her, and becomes what it was (models/palate.lua).
--
-- Three bodies it takes (Combat.devour): a corpse or a downed body of EITHER side, and any living body
-- of her OWN side -- settled on review 2026-09-23, "have her eat the living", answered "her own side,
-- any time". So the beasts walking in to help her are also walking in to be eaten, and the question the
-- fight asks is which of them reach her.
--
-- WHAT IT PAYS, AND WHY THE GORGED. The heal is a tenth of her ceiling, and the power is whatever the
-- body gives up -- but the power is granted on the live path only (the forecast must never hand her
-- one), and a heal forecasts as nothing on a body already at full. Left at that, the planner would read
-- a full-health Gula eating her own wolf as an action that accomplishes nothing and never take it. So a
-- meal also leaves her Gorged (the chimera's status: +6 damage for about two turns), which is true of an
-- apex that has just eaten and is the one thing the forecast can see her gain.
--
-- It is her whole action and costs nothing else: eating is instead of killing, which is the price.
local Palate = require("models.palate")

-- Choose the meal the same way the AI's rule sees it (Palate.edibleNear): a body whose power she does
-- not hold before one she does, the dead before the living. Read-only, so it is safe under the forecast.
local function pick(fx)
    local list = fx.combat and fx.user and Palate.edibleNear(fx.combat, fx.user) or {}
    return list[1]
end

return {
    name = "Devour",
    description = "Eats an adjacent corpse, downed body or ally, healing and taking its power.",
    flavor = "She does not chew. She has never once had to.",
    sprite = "assets/items/ability_devour.png",
    type = "ability",
    class = "creature",
    tags = { "natural" },
    noSteal = true,
    activeAbility = {
        target = "self",
        range = 0,
        speed = 4,
        support = true, -- a meal is aimed at herself: preview green, and the planner scores her own gain
        ai = { priority = "high", act = "support", label = "something to eat is beside her",
               whenFn = function(ctx)
                   return #Palate.edibleNear(ctx.combat, ctx.unit) > 0
               end },
        effect = function(fx)
            local u = fx.user
            local body = pick(fx)
            if not body then return end
            if not fx.devour(body) then return end
            local hp = u.char and u.char.stats and u.char.stats.health
            local amount = math.floor(((hp and hp.max) or 0) * 0.10 + 0.5)
            if amount > 0 then fx.heal(u, amount) end
            fx.applyStatus(u, "status_gorged")
        end,
    },
}
