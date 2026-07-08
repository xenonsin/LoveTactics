return {
    name = "Healing Potion",
    description = "Restores health to an ally. Consumed on use.",
    sprite = "assets/items/potion.png",
    type = "consumable",
    tags = { "potion", "restorative" },
    activeAbility = {
        name = "Drink",
        target = "ally", -- includes the user (a unit is its own ally)
        range = 1,
        speed = 2,
        consumesItem = true, -- removed from inventory after use
        power = 30, -- the amount restored; Power is the balance knob for the heal too
        effect = function(fx)
            fx.heal(fx.target, fx.power) -- restore Power HP via the shared heal helper
        end,
    },
}
