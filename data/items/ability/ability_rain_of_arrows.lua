-- Rain of Arrows: a volley that saturates a 3x3 area around the target. It can only be loosed when
-- a BOW sits adjacent to it in the 3x3 item grid (diagonals included) -- the arrows need a bow to
-- fire them. Combat.adjacencyMet gates the cast (and the battle UI's arm), and Combat.adjacencyLinks
-- draws a connector line to the bow that satisfies the requirement.
return {
    name = "Rain of Arrows",
    description = "A volley blanketing a 3x3 area. Requires an adjacent bow.",
    sprite = "assets/items/ability_rain_of_arrows.png",
    type = "ability",
    tags = { "pierce", "physical" },
    class = "hunter",
    price = 340,
    repRank = 3,
    activeAbility = {
        name = "Rain of Arrows",
        -- A saturating volley is aimed at a CELL, not a single foe: it can be centred on any
        -- walkable tile in range -- empty ground, an enemy, or one of your own (allowOccupied) --
        -- and the blast then sweeps everyone standing in the 3x3, friend and foe alike.
        target = "tile",
        allowOccupied = true,
        range = 4,
        requiresSight = true, -- arrows need a clear arc to the target cell
        speed = 5,
        cost = { stat = "stamina", amount = 10 },
        power = { 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10 }, -- per-target damage = power + the caster's Damage, minus Defense
        aoe = { radius = 1, shape = "square" }, -- 3x3 burst around the aimed cell (corners included)
        requiresAdjacent = { type = "weapon", tag = "bow" }, -- a bow must sit adjacent in the grid
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                fx.damage(u)
            end
        end,
    },
}
