-- The inverse of Push: drag a distant foe up against you. It needs a clear line (`requiresSight`,
-- and Combat.pull checks again) -- you cannot hook what you cannot see -- and the target is walked
-- toward you one tile at a time until it stands adjacent, setting off every trap and hazard it is
-- dragged across. A unit in the way stops it short.
--
-- Pulls an archer out of its dead zone, or a healer out of the back line and into the melee.
return {
    name = "Pull",
    description = "Haul a foe you can see into an adjacent space. It triggers anything it is dragged over.",
    sprite = "assets/items/ability_pull.png",
    type = "ability",
    tags = { "impact", "physical" },
    activeAbility = {
        target = "enemy",
        range = 4,
        minRange = 2, -- pointless on someone already beside you
        requiresSight = true,
        speed = 3,
        cost = { stat = "stamina", amount = 6 },
        effect = function(fx)
            fx.pull(fx.target)
        end,
    },
}
