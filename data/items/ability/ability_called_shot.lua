-- Called Shot: the hunter's follow-up to Mark Target. Against a Marked foe the arrow finds the painted
-- spot and hits for double; against anyone else it is an ordinary shot. Pairs directly with
-- data/items/ability/ability_mark_target.lua. Requires an adjacent bow in the grid.
return {
    name = "Called Shot",
    description = "A precise shot that doubles its damage against a marked foe. Requires an adjacent bow.",
    sprite = "assets/items/ability_called_shot.png",
    type = "ability",
    tags = { "pierce", "physical" },
    class = "hunter",
    price = 260,
    repRank = 3,
    activeAbility = {
        name = "Called Shot",
        target = "enemy",
        range = 5,
        minRange = 2,
        requiresSight = true,
        speed = 4,
        cost = { stat = "stamina", amount = 8 },
        requiresAdjacent = { type = "weapon", tag = "bow" },
        damage = { 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 },
        effect = function(fx)
            local t = fx.target
            if not t then return end
            if fx.hasStatus(t, "mark") then
                fx.damage(t, { amount = fx.amount * 2 })
            else
                fx.damage(t)
            end
        end,
    },
}
