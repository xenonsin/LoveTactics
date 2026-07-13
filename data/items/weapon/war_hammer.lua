-- A war hammer: a single ponderous swing that lands like a falling tree and leaves the target reeling.
-- It hits hard and STUNS -- shoving the victim down the turn order (data/status/stun.lua) -- but it is
-- brutally slow to wind up (a high `speed`), so you buy the stun with a big chunk of your own tempo.
return {
    name = "War Hammer",
    description = "A crushing overhead blow that stuns the target. Devastating, and very slow to swing.",
    sprite = "assets/items/war_hammer.png",
    type = "weapon",
    tags = { "blunt", "impact", "physical", "melee" },
    class = "fighter",
    price = 260,
    repRank = 3,
    activeAbility = {
        name = "Smash",
        target = "enemy",
        range = 1,
        speed = 7, -- ponderous: you pay for the stun in turn order
        cost = { stat = "stamina", amount = 12 },
        power = 12,
        effect = function(fx)
            fx.damage(fx.target)
            fx.applyStatus(fx.target, "stun")
        end,
    },
}
