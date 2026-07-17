-- A flask of supercooled brine that bursts in a 3x3 and encases everything caught in it in ice
-- (data/status/freeze.lua): each victim is shoved down the turn order AND left brittle -- taking
-- extra damage from crush and fire until the ice melts. Like the Flash Bomb, the control IS the
-- payload: it carries no damage of its own, so it wants a cluster to lock down, not to hurt.
--
-- The blast catches allies too, so mind your own line -- and note the combo it sets up: a frozen
-- foe is wide open to a hammer (crush) or a torch (fire) on the very next turn. Carries no "magical"
-- tag; the freeze is chemistry, and takes hold whatever the target's magic defense.
return {
    name = "Ice Bomb",
    description = "Inflicts Frozen on everything in the target area. Deals no damage.",
    flavor = "Supercooled brine, sold by a shop that will not insure you against carrying it badly.",
    sprite = "assets/items/ice_bomb.png",
    type = "consumable",
    tags = { "ice" }, -- no "magical": the cold is chemistry
    class = "alchemist",
    price = 160,
    repRank = 2,
    activeAbility = {
        target = "tile", -- thrown at a foe and bursts around it, like Fire Bomb / Flash Bomb
        allowOccupied = true,
        range = 3,
        requiresSight = true,
        speed = 4,
        cost = { stat = "stamina", amount = 5 },
        consumesItem = true,
        aoe = { radius = 1, shape = "square" }, -- 3x3 frozen area
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                fx.applyStatus(u, "status_freeze")
            end
        end,
    },
}
