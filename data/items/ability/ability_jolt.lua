-- Outpour: the mage's Storm Vessel payoff in mana (docs/engines.md). Empty the whole storm pool and take
-- 4 mana back per Storm. Mana never regenerates mid-fight, so a mage carrying this turns waiting into
-- the one resource nobody else can make -- a payoff that is not damage, by the author's rule that each
-- engine pays in what its class is about.
--
-- Reworked from Jolt (2026-11-18), a stun bolt that was the same verb as Minor Shock at rung 0. Named in
-- round 3 to follow the vessel (the working name was Discharge). The id stays for saves and drop lists.
return {
    name = "Outpour",
    description = "Consumes all Storm. Restores 4 mana per Storm.",
    flavor = "The apprentices are told never to do this indoors. The masters do it at their desks.",
    sprite = "assets/items/ability_jolt.png",
    type = "ability",
    tags = { "lightning", "magical" },
    class = "mage",
    price = 695,
    unlockLevel = 14,
    charge = { key = "storm", from = { "turnTaken" }, max = 3 },
    activeAbility = {
        target = "self",
        range = 0,
        speed = 2,
        support = true,
        perStorm = 4,
        spendsCharge = "storm",
        counter = function(unit)
            return unit and unit.char and require("models.combat").chargePool(unit, "storm") or 0
        end,
        counterEmpty = "No Storm gathered",
        effect = function(fx)
            local n = fx.spendCharge("storm")
            if n <= 0 then return end
            fx.restore(fx.user, "mana", n * (fx.item.activeAbility.perStorm or 4))
        end,
    },
}
