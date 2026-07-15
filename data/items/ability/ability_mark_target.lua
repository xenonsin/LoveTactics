-- Mark Target: paint a foe for the kill. Applies the Mark status (defense and magic defense cut), which
-- both softens it for the whole party and arms the hunter's Called Shot. No damage of its own -- it is
-- setup, not a strike. Requires an adjacent ranged weapon in the grid.
return {
    name = "Mark Target",
    description = "Paint a foe: its defense and magic defense drop. Requires an adjacent ranged weapon.",
    sprite = "assets/items/ability_mark_target.png",
    type = "ability",
    tags = { "utility" },
    class = "hunter",
    price = 180,
    repRank = 2,
    activeAbility = {
        target = "enemy",
        range = 5,
        requiresSight = true,
        speed = 3,
        cost = { stat = "stamina", amount = 4 },
        requiresAdjacent = { type = "weapon", tag = "ranged" },
        effect = function(fx)
            fx.applyStatus(fx.target, "mark")
        end,
    },
}
