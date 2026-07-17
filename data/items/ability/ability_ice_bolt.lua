-- Ice Bolt: a shard of ice that wounds one foe and leaves it Frozen (data/status/freeze.lua) --
-- shoving it down the turn order like a Stun, but the ice is brittle: a Frozen foe takes extra damage
-- from crush and fire, so the classic follow-up is an Earth Elemental's Stone Fists or a Fire Bolt.
-- The single-target ice counterpart to Fire Bolt. Scales with magic.
return {
    name = "Ice Bolt",
    description = "Deals damage and inflicts Frozen: delayed, and brittle to crush and fire.",
    flavor = "The shard is only the setup. The hammer that follows is the argument.",
    sprite = "assets/items/ability_ice_bolt.png",
    type = "ability",
    tags = { "ice", "magical" },
    class = "mage",
    price = 160,
    repRank = 2,
    activeAbility = {
        target = "enemy",
        range = 3,
        requiresSight = true,
        speed = 3,
        cost = { stat = "mana", amount = 10 },
        damage = { 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10 }, -- balances both the hit AND the freeze delay below
        effect = function(fx)
            -- The freeze rides the blow so it lands before the target can react to it. It is applied
            -- after mitigation is settled, so Frozen's own crush/fire `vulnerable` never feeds this
            -- bolt -- the ice has to survive a turn before anyone can shatter it. Delay scales with Power.
            fx.damage(fx.target, { inflicts = { id = "status_freeze", magnitude = fx.amount } })
        end,
    },
}
