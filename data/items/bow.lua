return {
    name = "Bow",
    description = "Fires an arrow at a foe up to three tiles away.",
    sprite = "assets/items/bow.png",
    type = "weapon",
    tags = { "bow", "pierce", "physical" },
    activeAbility = {
        name = "Shoot",
        target = "enemy",
        range = 3,
        speed = 2, -- lighter/faster than the sword
        cost = { stat = "stamina", amount = 6 },
        effect = function(fx)
            fx.damage(fx.target, { power = 1.0 })
        end,
    },
}
