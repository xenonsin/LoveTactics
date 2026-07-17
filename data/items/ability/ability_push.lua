-- Pure displacement: no damage of its own, but it drives an adjacent foe three tiles straight back.
-- The payoff is positional -- shove someone off a vantage point, into a fire hazard, over a spike
-- trap, or hard against a wall (a stopped shove deals the Power as impact damage to the foe AND to
-- whatever it slammed into). See Combat.knockback.
return {
    name = "Push",
    description = "Drives an adjacent foe three tiles back. A collision hurts both sides.",
    flavor = "No damage of its own. The wall, the fire and the spikes do all of the talking.",
    sprite = "assets/items/ability_push.png",
    type = "ability",
    tags = { "impact", "physical" },
    class = "knight",
    price = 200,
    repRank = 2,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 3,
        cost = { stat = "stamina", amount = 5 },
        damage = { 6, 7, 7, 8, 8, 9, 10, 10, 11, 11, 12 },
        effect = function(fx)
            fx.knockback(fx.target, 3, { amount = fx.amount })
        end,
    },
}
