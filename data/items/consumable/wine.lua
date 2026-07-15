-- Wine: a swig of courage in a bottle. Drunk by an ally (or yourself), it applies the Drunk status
-- (data/status/drunk.lua) -- more Damage, less guard -- and, crucially, switches on Drunken Fist for a
-- monk who carries one. Consumed on use. A deliberate trade, not a heal: you drink to hit harder and
-- gamble on not getting hit back.
return {
    name = "Wine",
    description = "A hearty draught. The drinker becomes Drunk: +Damage, but a looser guard.",
    sprite = "assets/items/wine.png",
    type = "consumable",
    tags = { "drink" },
    class = "priest",
    price = 40,
    repRank = 1,
    activeAbility = {
        target = "ally", -- includes the user (a unit is its own ally)
        range = 1,
        speed = 2,
        consumesItem = true, -- removed from inventory after use
        effect = function(fx)
            fx.applyStatus(fx.target, "drunk")
        end,
    },
}
