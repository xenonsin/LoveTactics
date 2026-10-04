-- MEGATHERIUM SWEEP: the Old Sloth's own blow (data/characters/character_old_sloth.lua). Approved 2026-10-04 on
-- "Sloth's Bestiary", slice A: "it spends the bank as ring sweeps: each banked turn sweeps every body beside it."
--
-- A RING, AIMED AT A TILE. Every melee weapon reaches at least 1 and a self-cast quotes 0, so the sweep is a tile
-- cast within 1 whose footprint is the ring around the WIELDER's 2x2 body wherever it was aimed (`aoe.cells`,
-- SlothBeasts.ringCells) -- Titan's Chain's shape. It goes round once for the turn and once more per banked turn,
-- and strikes foes only, as the Titan's does. The bank is spent through fx.clearStatus, inert in the previews.
local Curve = require("models.curve")

local function ring(combat, tx, ty, unit)
    return require("models.sloth_beasts").ringCells(unit or { x = tx, y = ty, w = 2, h = 2 })
end

return {
    name = "Megatherium Sweep",
    description = "Hits every foe beside it, once and once more for each turn banked.",
    flavor = "The ground sloth's grandmother, and she remembers when all of this was trees.",
    sprite = "assets/items/weapon_megatherium_sweep.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "slash", "physical", "melee" },
    noSteal = true, -- a creature's body is not loot
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 1,
        speed = 7,
        cost = { stat = "stamina", amount = 8 },
        damage = Curve.ramp(5, 15), -- per foe, per sweep: the bank is the multiplier
        aoe = { cells = ring },
        effect = function(fx)
            local u = fx.user
            local sweeps = require("models.sloth_beasts").swings(u)
            if sweeps > 1 then fx.clearStatus(u, "status_banked") end
            for _ = 1, sweeps do
                for _, t in ipairs(fx.aoeUnits()) do
                    if t.alive and t ~= u and t.side ~= u.side then fx.damage(t) end
                end
            end
        end,
    },
}
