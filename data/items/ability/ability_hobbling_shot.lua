-- Hobbling Shot: an arrow to the leg. Modest damage, then the target is Crippled (data/status/cripple.lua)
-- -- its movement is cut for a time, so it still moves but far less. The softer sibling of Pinning Shot:
-- it slows a foe rather than pinning it outright, and it lasts. Requires an adjacent bow in the grid.
return {
    name = "Hobbling Shot",
    description = "Damage a foe and cripple its movement. Requires an adjacent bow.",
    sprite = "assets/items/ability_hobbling_shot.png",
    type = "ability",
    tags = { "pierce", "physical" },
    class = "hunter",
    price = 200,
    repRank = 2,
    activeAbility = {
        target = "enemy",
        range = 4,
        minRange = 2,
        requiresSight = true,
        speed = 4,
        cost = { stat = "stamina", amount = 7 },
        damage = { 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9 },
        requiresAdjacent = { type = "weapon", tag = "bow" },
        effect = function(fx)
            fx.damage(fx.target)
            fx.applyStatus(fx.target, "cripple")
        end,
    },
}
