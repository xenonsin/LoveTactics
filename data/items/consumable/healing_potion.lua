return {
    name = "Healing Potion",
    description = "Restores health to an ally. Consumed on use.",
    sprite = "assets/items/potion.png",
    type = "consumable",
    tags = { "potion", "restorative" },
    class = "priest",
    price = 35,
    repRank = 1,
    activeAbility = {
        name = "Drink",
        target = "ally", -- includes the user (a unit is its own ally)
        range = 1,
        speed = 2,
        consumesItem = true, -- removed from inventory after use
        healing = { 30, 33, 36, 39, 42, 45, 48, 51, 54, 57, 60 }, -- the amount restored; Power is the balance knob for the heal too
        effect = function(fx)
            fx.heal(fx.target, fx.amount) -- restore Power HP via the shared heal helper
        end,
    },
}
