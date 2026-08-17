-- Osric's bound relic (Crusader). The same hand does both jobs, and this is the ground it walks on.
--
-- NOT A HOLY BLOW THAT HEALS THE ADJACENT -- that is the shelf's own idea (Smite, Reckoning, Zealous
-- Charge) with a bigger number on it, and it was cut for exactly that. This lays a MARCH: consecrated
-- ground under him and ahead of him, healing whoever stands in it and burning whatever will not move.
-- Ground that keeps working after the turn it was made in is the thing nothing else on either parent
-- shelf does.
--
-- IT SPENDS ZEAL, and Zeal is the multiclass's shared pool (Combat.chargeDef): banked on kills AND on
-- heals alike, which is R2's rule -- a crusader who spent the fight healing still reaches the payoff.
-- Vow of the March fills it, Crusader's Tabard scales with how much is held, Reckoning competes for the
-- same purse. That competition is the build's real decision.
local Curve = require("models.curve")

return {
    name = "The Marching Vow",
    description = "Spends your Zeal to lay consecrated ground around you, healing your side and burning theirs.",
    flavor = "The vow was never to win. It was to keep going, and to bring the ground with him.",
    sprite = "assets/items/sig_marching_vow.png",
    type = "armor",
    tags = { "signature", "holy" },
    class = "priest",
    discipline = "crusader",
    bound = true,
    bonus = { defense = Curve.ramp(2, 12), movement = -1 },
    -- It declares the pool it spends. Without this the relic would be INERT until the crusader also
    -- happened to own Vow of the March or the Tabard -- a signature that only works if you bought
    -- something else is not a signature (tests/charge_spec.lua pins the rule). Same two tallies the
    -- shelf's own pool banks from, so a crusader carrying both has one Zeal rather than two.
    charge = { key = "zeal", from = { "foeDown", "allyHealed" }, max = 10 },
    activeAbility = {
        target = "self",
        range = 0,
        speed = 6,
        cost = { stat = "stamina", amount = 10 },
        aoe = { radius = 2, shape = "square" },
        description = "Consecrates the ground around you, scaled by the Zeal you spend.",
        -- The pool made visible on the slot, so he can see what the march is worth before committing
        -- it. Reads the same pool the effect spends, so badge and cast can never disagree.
        counter = function(unit)
            return unit and require("models.combat").chargePool(unit, "zeal") or 0
        end,
        counterLabel = "Zeal",
        -- A CENSUS on his own pool rather than an event count: Zeal is derived from two tallies at once
        -- (Combat.chargePool), so no single `event` could read it. The clause asks the pool directly.
        unlock = {
            field = { of = "unit", side = "self", count = 1,
                      test = function(u)
                          return require("models.combat").chargePool(u, "zeal") >= 6
                      end },
            text = "Hold 6 Zeal",
        },
        effect = function(fx)
            -- Spend it ALL: the march is worth what he brought to it, and holding some back for the
            -- Tabard is the choice made before pressing this rather than inside it.
            local spent = fx.spendCharge("zeal")
            if spent <= 0 then return end
            for _, cell in ipairs(fx.aoeCells()) do
                fx.placeHazard(cell.x, cell.y, "hazard_sacred", { side = fx.user.side })
            end
        end,
    },
}
