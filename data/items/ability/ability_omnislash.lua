-- Cascade: the fighter's Tempo payoff (docs/engines.md). One blow for every Tempo banked, up to six, and
-- the pool is spent. With no Tempo it will not swing at all -- the engine's payoff is worth exactly the
-- quick actions that fed it, and a fighter who walked has thrown them away.
--
-- Each blow is a whole separate blow and loses the target's armour on its own, which is the price of the
-- engine: many light hits are the answer to a crowd of soft bodies and a poor one to plate. It competes
-- with the big swing rather than replacing it.
--
-- Reworked from Omnislash (2026-11-18), whose scaling off adjacent weapons was a stat stick in a cell.
-- Renamed from the round's working name Flurry, which is the monk's.
local Curve = require("models.curve")

return {
    name = "Cascade",
    description = "Strikes once per Tempo, up to 6. Consumes all Tempo.",
    flavor = "Nobody in the stands counts the blows. They count the ones that land.",
    sprite = "assets/items/ability_omnislash.png",
    type = "ability",
    class = "fighter",
    price = 390,
    unlockLevel = 7,
    tags = { "slash", "physical" },
    charge = { key = "tempo", from = { "quickAction" }, max = 6, resetOn = "moved" },
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 8 },
        damage = Curve.ramp(4, 14), -- per blow
        maxBlows = 6,
        spendsCharge = "tempo",
        counter = function(unit)
            return unit and unit.char and require("models.combat").chargePool(unit, "tempo") or 0
        end,
        counterEmpty = "No Tempo to spend",
        effect = function(fx)
            local have = fx.chargePool("tempo")
            local blows = math.min(have, fx.item.activeAbility.maxBlows or 6)
            if blows <= 0 then return end
            fx.spendCharge("tempo")
            for _ = 1, blows do
                if not (fx.target and fx.target.alive) then break end
                fx.damage(fx.target)
            end
        end,
    },
}
