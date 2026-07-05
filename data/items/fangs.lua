-- A beast's natural weapon: the enemy-side equivalent of a melee weapon, so wolves and
-- boars have both an attack and an initiative (average ability speed) without "holding" a
-- crafted item. Given to beast blueprints via startingItems.
return {
    name = "Fangs",
    description = "Bite an adjacent foe.",
    sprite = "assets/items/fangs.png",
    type = "weapon",
    tags = { "bite", "physical" },
    activeAbility = {
        name = "Bite",
        target = "enemy",
        range = 1,
        speed = 2,
        cost = { stat = "stamina", amount = 5 },
        effect = function(fx)
            fx.damage(fx.target, { power = 1.0 })
        end,
    },
}
