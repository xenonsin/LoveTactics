-- An elemental's natural weapon, the magical counterpart to a beast's fangs: it gives the
-- Fire Elemental both an attack and an initiative (the average ability speed) without "holding" a
-- crafted item. `noSteal` because a pickpocket cannot lift the fire off a creature made of it.
-- Given to the blueprint via startingItems.
return {
    name = "Flame Fists",
    description = "Scorch an adjacent foe.",
    sprite = "assets/items/flame_fists.png",
    type = "weapon",
    tags = { "natural", "fire", "magical", "melee" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 2,
        cost = { stat = "stamina", amount = 5 },
        damage = { 6, 7, 7, 8, 8, 9, 10, 10, 11, 11, 12 },
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
