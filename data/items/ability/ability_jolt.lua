-- An ability that jolts a foe: light magical damage plus the "status_stun" status, which shoves the
-- target down the turn order (see data/status/stun.lua). Demonstrates fx.applyStatus from an ability.
return {
    name = "Jolt",
    description = "Deals light damage and inflicts Stun.",
    flavor = "An apprentice's first spell, and the first thing they overestimate.",
    sprite = "assets/items/ability_jolt.png",
    type = "ability",
    tags = { "lightning", "magical" },
    class = "mage",
    price = 90,
    repRank = 1,
    activeAbility = {
        target = "enemy",
        range = 3,
        requiresSight = true, -- a bolt needs a clear line: terrain cover blocks it
        -- Slower than a sword swing, and that is the price of what it buys. A Jolt does almost no
        -- damage; what it sells is TEMPO -- five ticks off the target's next turn -- and an ability
        -- that hands you the initiative should cost some of your own to throw. (It is also what makes
        -- the prologue's closing beat land: the caster comes back around just BEHIND the ally the
        -- stun bought a turn for, so the ally swings first and the player still lands the last blow.
        -- See data/tutorials/village.lua.)
        speed = 4,
        cost = { stat = "mana", amount = 10 },
        damage = { 4, 4, 5, 5, 6, 6, 6, 7, 7, 8, 8 }, -- balances both the hit AND the stun delay below
        effect = function(fx)
            -- power + the caster's MagicDamage, minus MagicDefense. The stun rides the blow so it
            -- lands before the target can react to it; the delay still scales with Power.
            fx.damage(fx.target, { inflicts = { id = "status_stun", magnitude = fx.amount } })
        end,
    },
}
