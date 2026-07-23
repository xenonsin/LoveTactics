-- Ball Bearings: a fistful of them, thrown underfoot. Nobody crossing the scatter keeps their footing.
-- It Cripples everything in a small burst and draws no blood -- guile's denial, on the same shape as the
-- Net (a thrown control consumable that deals no damage) but hitting an AREA rather than one foe, and
-- slowing rather than pinning.
--
-- Why the rogue's and not a trap on the hunter's shelf: this is thrown in the moment, not laid in
-- advance (compare the hunter's Caltrop Greaves, which SEED the ground you have already walked). A rogue
-- does not prepare the floor; it changes it under the cursor, right when the line is about to close.
-- Cripple rather than Root because greed keeps the exit open -- it wants the enemy slow, so the rogue is
-- the faster thing in the room, not both of them standing still.
return {
    name = "Ball Bearings",
    description = "Scatters underfoot: Cripples everything in a small area. Deals no damage.",
    flavor = "The Undercroft sells dignity by the handful. This is what it costs a charging line of it.",
    sprite = "assets/items/ball_bearings.png",
    type = "consumable",
    tags = { "snare" },
    class = "rogue",
    price = 100,
    repRank = 1,
    activeAbility = {
        target = "tile", -- thrown at a tile and bursts around it, like the Flash Bomb
        allowOccupied = true,
        range = 3,
        requiresSight = true,
        speed = 4,
        cost = { stat = "stamina", amount = 4 },
        consumesItem = true,
        aoe = { radius = 1, shape = "square" },
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                fx.applyStatus(u, "status_cripple")
            end
        end,
    },
}
