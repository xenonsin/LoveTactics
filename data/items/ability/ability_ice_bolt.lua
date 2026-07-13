-- Ice Bolt: a shard of ice that wounds one foe and leaves it Frozen (data/status/freeze.lua) --
-- shoving it down the turn order like a Stun, but the ice is brittle: a Frozen foe takes extra damage
-- from crush and fire, so the classic follow-up is an Earth Elemental's Stone Fists or a Fire Bolt.
-- The single-target ice counterpart to Fire Bolt. Scales with magic.
return {
    name = "Ice Bolt",
    description = "Pierce a foe with ice, freezing it (delayed; weak to crush and fire).",
    sprite = "assets/items/ability_ice_bolt.png",
    type = "ability",
    tags = { "ice", "magical" },
    class = "mage",
    price = 160,
    repRank = 2,
    activeAbility = {
        name = "Ice Bolt",
        target = "enemy",
        range = 3,
        requiresSight = true,
        speed = 3,
        cost = { stat = "mana", amount = 10 },
        power = { 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10 }, -- balances both the hit AND the freeze delay below
        effect = function(fx)
            fx.damage(fx.target)
            fx.applyStatus(fx.target, "freeze", { magnitude = fx.power }) -- delay scales with Power
        end,
    },
}
