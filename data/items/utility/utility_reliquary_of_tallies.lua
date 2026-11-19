-- The Reliquary of Tallies: the priest's Overflow bank (docs/engines.md). Healing the bearer casts past
-- full fills it with Radiance, a point per point, up to twenty (the `radiance` pool, fed by
-- Engine.overheal's `overheal` tally on the HEALER). Spent here, the whole bank heals one ally.
--
-- The priest root's own spend is the heal. The other spends are their own items on the leaves that
-- already do those things (the author's call, round 3): Judgement on the Crusader, Aegis of Plenty on the
-- Paladin, the Overflowing Cup on the Monk, the Votive Flame on the Theurge.
--
-- Reworked 2026-11-18. It used to fill with every ally lost, which made it the catalogue's one item that
-- was best in the fights the party was closest to losing. It still arrives empty and still pays late.
return {
    name = "The Reliquary of Tallies",
    description = "Healing past full fills it with Radiance, up to 20. Consume it all to heal an ally for that much.",
    flavor = "The Cathedral keeps one in every chapter house. They are always, always full.",
    sprite = "assets/items/utility_reliquary_of_tallies.png",
    type = "utility",
    tags = { "holy" },
    class = "priest",
    unlockLevel = 1,
    charge = { key = "radiance", from = { "overheal" }, max = 20 },
    activeAbility = {
        target = "ally",
        range = 4,
        requiresSight = true,
        speed = 3,
        support = true,
        cost = { stat = "mana", amount = 6 },
        spendsCharge = "radiance",
        counter = function(unit)
            return unit and unit.char and require("models.combat").chargePool(unit, "radiance") or 0
        end,
        counterEmpty = "The reliquary is empty: heal past full to fill it",
        effect = function(fx)
            local have = fx.chargePool("radiance")
            if have <= 0 then return end
            fx.spendCharge("radiance")
            -- A heal PAID FOR with Radiance does not refill the bank that paid it.
            fx.noBank = true
            fx.heal(fx.target, have)
            fx.noBank = nil
        end,
    },
    bonus = { magicDefense = 1, luck = 1 },
}
