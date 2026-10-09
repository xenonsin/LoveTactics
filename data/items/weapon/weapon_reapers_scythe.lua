-- REAPER'S SCYTHE: the Reaper's own, and the Harvest itself ("The Crown's Bestiary", slice C, approved 2026-10-09): "A
-- scythe sweep of every tile around it. Any body in the sweep under a quarter health is Downed at once."
--
-- A RING WEAPON, so a tile cast that sweeps the wielder's ring: every melee weapon must reach at least 1, and a
-- self-cast must quote range 0, so the sweep is aimed at any tile beside the Reaper and covers all eight around it
-- whichever was aimed at (`aoe.cells`, the Titan's Chain's arrangement at reach 1, with the corners). Foes only, as
-- every sweep in this game is. Each foe in it under the line is reaped (GatePit.reap: a full-health, armour-blind
-- blow, Coup de Grace's own, and never a boss); the rest take the sweep.
--
-- The counter is the review's: heal the wounded above the line, pull them out of its ring, or Root or Stun it before
-- it reaches a weak body. Creature kit, never loot -- the Assassin's The Harvest is the trophy.
local Curve = require("models.curve")

-- Every board cell around the wielder (Chebyshev 1), whatever tile was aimed at.
local function ring(combat, tx, ty, unit)
    local cx, cy = unit and unit.x or tx, unit and unit.y or ty
    local cells = {}
    for dx = -1, 1 do
        for dy = -1, 1 do
            if dx ~= 0 or dy ~= 0 then cells[#cells + 1] = { x = cx + dx, y = cy + dy } end
        end
    end
    return cells
end

return {
    name = "Reaper's Scythe",
    description = "Sweeps every tile around you. A foe in the sweep under a quarter health is downed at once.",
    flavor = "It has never once been in a hurry. Everyone it has met was early.",
    sprite = "assets/items/weapon_reapers_scythe.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "slash", "physical", "melee" },
    noSteal = true, -- a creature's body is not loot
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 1,
        speed = 5,
        cost = { stat = "stamina", amount = 8 },
        damage = Curve.ramp(9, 19),
        aoe = { cells = ring },
        effect = function(fx)
            local GatePit = require("models.gate_and_pit")
            for _, t in ipairs(fx.aoeUnits()) do
                if t.alive and t ~= fx.user and t.side ~= fx.user.side then GatePit.reap(fx, t) end
            end
        end,
    },
}
