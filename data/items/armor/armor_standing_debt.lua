-- Ilse's bound relic (Sentinel). Intercept, taken past the point where it is a favour.
--
-- THE SHELF ALREADY REDIRECTS ONE BLOW. Warden's Oath takes the first hit each turn aimed at an
-- adjacent ally; Shared Burden and The Lent Aegis split and lend what lands. Every one of those is a
-- discount on somebody else's wound. This is not a discount -- for two turns she is the ONLY thing on
-- the board that can be aimed at, and the fight has to come through her whether it wants to or not.
--
-- Taunt is the existing verb for that (data/status/status_taunt.lua), applied to every foe rather than
-- one, which is what turns a redirect into a rule. What she keeps afterwards is what she took: every
-- blow weathered in those two turns hardens her for the rest of the fight, so a sentinel who survives
-- the debt is a wall that was paid for.
--
-- THE CENSUS IS THREE WOUNDED ALLIES, and it is deliberately not "blows answered": a sentinel who has
-- been answering is a sentinel whose line is holding, and the moment worth spending this on is the one
-- where it is not. It shuts again the moment they are healed, which is the right way round.
local Curve = require("models.curve")

return {
    name = "The Standing Debt",
    description = "For two turns nothing can aim at anyone else, and every blow taken hardens you for good.",
    flavor = "She does not offer. She simply stands where the answer has to go through.",
    sprite = "assets/items/sig_standing_debt.png",
    type = "armor",
    tags = { "signature", "shield" },
    class = "knight",
    discipline = "sentinel",
    bonus = { defense = Curve.ramp(3, 13), movement = -1 },
    -- The wall's stance, like every shield on this shelf: its brace climbs with the forge.
    waitBehavior = { kind = "defend", speed = 3, defense = Curve.ramp(5, 15) },
    activeAbility = {
        target = "self",
        range = 0,
        speed = 5,
        cost = { stat = "stamina", amount = 12 },
        description = "Taunts every foe on the field, and braces you behind it.",
        unlock = {
            field = { of = "unit", side = "ally", hpBelow = 0.5, count = 3 },
            text = "3 allies below half",
        },
        effect = function(fx)
            -- Every foe on the board, not the ones in reach: a debt that only bound the front rank
            -- would leave the archers to shoot past her, which is the whole thing she is refusing.
            for _, u in ipairs((fx.combat and fx.combat.units) or {}) do
                if u.alive and u.side ~= fx.user.side then
                    fx.applyStatus(u, "status_taunt")
                end
            end
            -- What she collects for standing there. Empowered is spent on a blow; this is Defending,
            -- which is the stance the shield already knows -- so the two turns read as a brace she
            -- chose rather than a buff she was handed.
            fx.applyStatus(fx.user, "status_defending")
        end,
    },
}
