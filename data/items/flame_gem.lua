return {
    name = "Flame Gem",
    description = "Hurls a fireball at a distant foe. Scales with magic.",
    sprite = "assets/items/flame_gem.png",
    type = "gem",
    tags = { "fire", "magical" }, -- the "magical" tag routes damage to magicDamage/magicDefense
    activeAbility = {
        name = "Fireball",
        target = "enemy",
        range = 3,
        speed = 4, -- powerful but slow
        cost = { stat = "mana", amount = 12 },
        effect = function(fx)
            fx.damage(fx.target, { power = 1.0 })
        end,
    },
}
