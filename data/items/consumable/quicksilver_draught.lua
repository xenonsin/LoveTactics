-- Crucible rank-1. Mana in a bottle, which the Arcanum considers an insult and buys anyway. It gives
-- back the one resource that never refills on its own between battles (see Player.restore and the
-- stamina/mana split in Combat.new) -- which is what makes a shelf of chemistry worth a mage's gold.
return {
    name = "Quicksilver Draught",
    description = "Bitter, bright, and gone in a swallow. Restores mana to an ally.",
    sprite = "assets/items/quicksilver_draught.png",
    type = "consumable",
    tags = { "potion", "restorative" },
    class = "alchemist",
    price = 60,
    repRank = 1,
    activeAbility = {
        name = "Drink",
        target = "ally", -- includes the user (a unit is its own ally)
        range = 1,
        speed = 2,
        consumesItem = true,
        restore = { 25, 28, 30, 33, 35, 38, 40, 43, 45, 48, 50 }, -- mana restored
        effect = function(fx)
            fx.restore(fx.target, "mana", fx.amount)
        end,
    },
}
