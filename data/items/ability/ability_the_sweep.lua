-- THE SWEEP: the Horned Twin's, once her sister has fallen. Approved 2026-09-27 ("The Oni of Wrath", round 2, the
-- Twins' elite): "her morning star sweeps every tile within 3 of her each turn."
--
-- Usable only under Full Horn Out (status_full_horn_out), and then it is her whole turn: the flail goes round
-- and strikes every foe within 3. Before her sister falls it does not exist, which is the choice the fight asks:
-- fell the hornless sister first, and this is what you have woken.
local Curve = require("models.curve")

return {
    name = "The Sweep",
    description = "Only under Full Horn Out. Strikes every foe within 3.",
    flavor = "The chain never stops once it starts. Neither does she.",
    sprite = "assets/items/ability_the_sweep.png",
    type = "ability",
    tags = { "impact", "physical" },
    class = "creature",
    noSteal = true,
    activeAbility = {
        target = "self",
        support = false,
        range = 0,
        speed = 4,
        cost = { stat = "stamina", amount = 6 },
        damage = Curve.ramp(12, 24),
        aoe = { shape = "square", radius = 3 },
        ai = { priority = "urgent", act = "cast" },
        usable = function(unit)
            if require("models.status").has(unit, "status_full_horn_out") then return true end
            return false, "only with her horn all the way out"
        end,
        effect = function(fx)
            local user = fx.user
            for _, u in ipairs(fx.aoeUnits()) do
                if u.alive and u.side ~= user.side then fx.damage(u) end
            end
        end,
    },
}
