-- Puffball: a Puffer's spore sac, thrown. It bursts over a square and Swoons everything in it -- both
-- sides, as every burst in the game is -- so the aim is the whole skill.
--
-- Swoon refuses harm and nothing else (data/status/status_swoon.lua): a line it catches still walks,
-- heals and braces, and cannot swing for a turn or two -- until something hits it. So it is the throw
-- that buys a company the exchange it was about to lose, not the throw that wins a fight.
--
-- `unstocked`: found only, off the mushroom folk (tests/discovery_spec.lua names it).
return {
    name = "Puffball",
    description = "Inflicts Swoon in area.",
    flavor = "Kick one in a field and you get a brown cloud. Kick one of these and you get a nap you did not want.",
    sprite = "assets/items/consumable_puffball.png",
    type = "consumable",
    tags = { "poison" },
    class = "bombardier",
    unstocked = true,
    unlockLevel = 1,
    activeAbility = {
        target = "tile", -- thrown at a foe and bursts around it, like the Flash Bomb
        allowOccupied = true,
        range = 3,
        requiresSight = true,
        speed = 4,
        cost = { stat = "stamina", amount = 4 },
        consumesItem = true,
        aoe = { radius = 1, shape = "square" },
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                fx.applyStatus(u, "status_swoon")
            end
        end,
    },
}
