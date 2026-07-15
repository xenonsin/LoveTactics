return {
    name = "Iron Sword",
    description = "A basic blade. Strikes an adjacent foe.",
    sprite = "assets/items/sword.png",
    type = "weapon",
    tags = { "sword", "slash", "physical", "melee" }, -- drive damage scaling + armor mitigation
    class = "fighter",
    price = 60,
    repRank = 1,
    activeAbility = {
        target = "enemy",
        range = 1, -- adjacent only (Manhattan distance)
        speed = 3, -- time cost: feeds initiative + pushes the actor back
        cost = { stat = "stamina", amount = 8 },
        -- damage = power + the wielder's Damage stat, minus the target's Defense. Power is a per-level
        -- table (levels 0..10): forging the blade steps its Power up the curve.
        --        level:  0  1  2  3  4  5  6  7  8  9  10
        damage = { 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 },
        effect = function(fx)
            fx.damage(fx.target) -- power + attack stat; tags default to the item's tags
        end,
    },
}
