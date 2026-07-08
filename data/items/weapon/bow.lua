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
        requiresSight = true, -- an arrow needs a clear line: terrain cover blocks the shot
        speed = 2, -- lighter/faster than the sword
        cost = { stat = "stamina", amount = 6 },
        power = 5,
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
