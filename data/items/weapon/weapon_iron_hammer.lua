-- A war hammer: a single ponderous swing that lands like a falling tree and leaves the target reeling.
-- It hits hard and STUNS -- shoving the victim down the turn order (data/status/stun.lua) -- but it is
-- brutally slow to wind up (a high `speed`), so you buy the stun with a big chunk of your own tempo.
return {
    name = "Iron Hammer",
    description = "Deals heavy damage and inflicts Stun.",
    flavor = "It lands like a falling tree. You buy the stun with your own tempo, and the price is never negotiable.",
    sprite = "assets/items/war_hammer.png",
    type = "weapon",
    tags = { "hammer", "impact", "physical", "melee" },
    hands = 2, -- a two-handed maul (Dual Wield can pair it only once forged to +5)
    class = "fighter",
    price = 260,
    repRank = 1, -- a family's base weapon is always rank 1 (docs/weapons.md)
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 7, -- ponderous: you pay for the stun in turn order
        cost = { stat = "stamina", amount = 12 },
        damage = { 12, 13, 14, 16, 17, 18, 19, 20, 22, 23, 24 },
        effect = function(fx)
            -- The stun rides the blow (`inflicts`) rather than following it: a hammer that stunned on
            -- the NEXT line would be answered by the very fighter it just rattled, because the counter
            -- fires from inside fx.damage. See Combat.dealFlatDamage.
            fx.damage(fx.target, { inflicts = "status_stun" })
        end,
    },
}
