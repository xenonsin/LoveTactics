return {
    name = "Iron Sword",
    description = "A basic blade. Strikes an adjacent foe.",
    sprite = "assets/items/sword.png",
    type = "weapon",
    tags = { "sword", "slash", "physical" }, -- drive damage scaling + armor mitigation
    activeAbility = {
        name = "Slash",
        target = "enemy",
        range = 1, -- adjacent only (Manhattan distance)
        speed = 3, -- time cost: feeds initiative + pushes the actor back
        cost = { stat = "stamina", amount = 8 },
        power = 6, -- damage = power + the wielder's Damage stat, minus the target's Defense
        effect = function(fx)
            fx.damage(fx.target) -- power + attack stat; tags default to the item's tags
        end,
    },
}
