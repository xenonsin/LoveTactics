return {
    name = "Bow",
    description = "Fires an arrow at a foe two to three tiles away -- too far for point-blank shots.",
    sprite = "assets/items/bow.png",
    type = "weapon",
    tags = { "bow", "pierce", "physical", "ranged" },
    class = "hunter",
    price = 80,
    repRank = 1,
    activeAbility = {
        name = "Shoot",
        target = "enemy",
        range = 3,
        minRange = 2, -- a bow can't fire at adjacent tiles: no point-blank shots
        requiresSight = true, -- an arrow needs a clear line: terrain cover blocks the shot
        speed = 2, -- lighter/faster than the sword
        cost = { stat = "stamina", amount = 6 },
        power = 5,
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
