-- Judgement: the Crusader's Overflow payoff (docs/engines.md). Every point of Radiance the bearer has
-- banked by healing past full, thrown at one foe as raw holy damage, and half again. Raw because the
-- bank is the price: armour does not get a second say over a number the priest already paid for in turns.
--
-- On the Crusader (fighter x priest) because it already strikes with holy damage at demons and the
-- undead, and demons burn.
return {
    name = "Judgement",
    description = "Consumes all Radiance. Deals that much raw holy damage, and half again.",
    flavor = "What the Cathedral gave freely, it may also take back.",
    sprite = "assets/items/ability_judgement.png",
    type = "ability",
    tags = { "holy", "magical" },
    class = "crusader",
    price = 420,
    unlockLevel = 8,
    -- Banks its own Radiance too, so it works without a Reliquary: the bearer's heals fill it.
    charge = { key = "radiance", from = { "overheal" }, max = 20 },
    activeAbility = {
        target = "enemy",
        range = 3,
        requiresSight = true,
        speed = 4,
        cost = { stat = "mana", amount = 10 },
        spendsCharge = "radiance",
        counter = function(unit)
            return unit and unit.char and require("models.combat").chargePool(unit, "radiance") or 0
        end,
        counterEmpty = "No Radiance banked",
        effect = function(fx)
            local have = fx.chargePool("radiance")
            if have <= 0 then return end
            fx.spendCharge("radiance")
            fx.flatDamage(fx.target, math.floor(have * 1.5), { "holy", "magical" })
        end,
    },
}
