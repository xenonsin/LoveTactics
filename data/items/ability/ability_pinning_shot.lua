-- Pinning Shot: an arrow through the foot. Modest damage, then the target is Rooted (data/status/root.lua)
-- -- it cannot move on its turn and still burns the time as if it had. Lock a charger in place and let
-- the line reposition around it. Requires an adjacent bow in the grid.
return {
    name = "Pinning Shot",
    description = "Damage a foe and root it in place. Requires an adjacent bow.",
    sprite = "assets/items/ability_pinning_shot.png",
    type = "ability",
    tags = { "pierce", "physical" },
    class = "hunter",
    price = 220,
    repRank = 2,
    activeAbility = {
        name = "Pinning Shot",
        target = "enemy",
        range = 4,
        minRange = 2,
        requiresSight = true,
        speed = 4,
        cost = { stat = "stamina", amount = 8 },
        damage = { 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9 },
        requiresAdjacent = { type = "weapon", tag = "bow" },
        effect = function(fx)
            fx.damage(fx.target)
            fx.applyStatus(fx.target, "root")
        end,
    },
}
