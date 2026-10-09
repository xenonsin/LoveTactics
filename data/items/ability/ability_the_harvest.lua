-- THE HARVEST: the Reaper's trophy ("The Crown's Bestiary", slice C, approved 2026-10-09), for an Assassin: "Range 0.
-- Sweep every tile around you: each foe under a quarter health is downed at once."
--
-- The Reaper's scythe as a cast. Coup de Grace, on the same shelf, finishes ONE adjacent foe under a quarter; this
-- sweeps the whole ring, so it is the finisher for a body that has walked into the middle of a broken line. Foes above
-- the line take the sweep (GatePit.reap); a boss is never reaped. Unstocked: it is only ever carried off the floor.
local Curve = require("models.curve")

return {
    name = "The Harvest",
    description = "Range 0. Sweep every tile around you: each foe under a quarter health is downed at once.",
    flavor = "The Undercroft calls it a finishing move. The Reaper calls it the season.",
    sprite = "assets/items/ability_the_harvest.png",
    type = "ability",
    tags = { "slash", "physical", "guile" },
    class = "assassin",
    unlockLevel = 15,
    unstocked = true,
    activeAbility = {
        target = "self",
        support = false,
        range = 0,
        speed = 5,
        cost = { stat = "stamina", amount = 10 },
        damage = Curve.ramp(16, 28),
        aoe = { shape = "square", radius = 1 },
        effect = function(fx)
            local GatePit = require("models.gate_and_pit")
            for _, t in ipairs(fx.aoeUnits()) do
                if t.alive and t ~= fx.user and t.side ~= fx.user.side then GatePit.reap(fx, t) end
            end
        end,
    },
}
