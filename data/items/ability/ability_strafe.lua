-- STRAFE: Avaritia's second third -- Smaug over Lake-town (reviewed 2026-09-25, "Avaritia, the Unspent").
-- Live only while she is Over the Deeps (her phase relic lays it at 60% and lifts it at 30%).
--
-- SHE TAKES WING (Aloft: out of reach) and marks a WHOLE ROW OR COLUMN of the cavern a turn ahead, through
-- the tile she aims at (models/hoard.lua's line). When the wind-up resolves she burns every tile of it --
-- both sides, heaps melting to Molten Gold -- and comes down at the far end of the line from where she rose.
-- Where she lands, the cave answers: three tiles near her are marked, and a turn later the roof comes down on
-- them (hazard_roof_falling -- damage and a Stun on whoever stayed, rubble on an empty tile).
--
-- The telegraph is exact, so a body caught in the line has misread it. Creature kit.
local Curve = require("models.curve")
local Status = require("models.status")

local ROOF = 3

-- The anchor of a 2x2 (or wider) body that fits on or beside cell `c`, or nil.
local function fitNear(combat, unit, c)
    local Combat = require("models.combat")
    local w, h = unit.w or 1, unit.h or 1
    for oy = 0, h - 1 do
        for ox = 0, w - 1 do
            local ax, ay = c.x - ox, c.y - oy
            if Combat.footprintFree(combat, w, h, ax, ay, unit) then return ax, ay end
        end
    end
    return nil
end

local function landing(combat, unit, cells)
    local Combat = require("models.combat")
    -- The far end is the end of the line further from where she rose.
    local first, last = cells[1], cells[#cells]
    if not (first and last) then return nil end
    local far = Combat.cellGap(first.x, first.y, unit) >= Combat.cellGap(last.x, last.y, unit)
    local step = far and 1 or -1
    local i = far and 1 or #cells
    while i >= 1 and i <= #cells do
        local ax, ay = fitNear(combat, unit, cells[i])
        if ax then return ax, ay end
        i = i + step
    end
    return nil
end

return {
    name = "Strafe",
    description = "Takes wing over a whole row or column. Next turn, burns every unit in it and lands at its end; the roof falls nearby.",
    flavor = "She has never once needed to look down to aim.",
    sprite = "assets/items/ability_strafe.png",
    type = "ability",
    tags = { "fire", "magical", "breath" },
    class = "creature",
    noSteal = true,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 12,
        speed = 4,
        windup = 5, -- a turn in the air, the line painted under her
        cooldown = 15,
        cost = { stat = "stamina", amount = 10 },
        damage = Curve.ramp(10, 26),
        channelStatus = "status_aloft",
        aoe = {
            cells = function(combat, tx, ty, unit)
                return require("models.hoard").line(combat, unit, tx, ty)
            end,
        },
        usable = function(unit)
            if not Status.has(unit, "status_over_the_deeps") then return false, "Grounded" end
            if Status.blocksForcedMove(unit) then return false, "Held to the ground" end
            return true
        end,
        ai = { priority = "high", act = "cast" },
        effect = function(fx)
            local u = fx.user
            if fx.clearStatus then fx.clearStatus(u, "status_aloft") end
            local cells = fx.aoeCells()
            for _, t in ipairs(fx.aoeUnits()) do
                if t ~= u and t.alive then fx.damage(t, { inflicts = "status_burn" }) end
            end
            local Hoard = require("models.hoard")
            Hoard.burnCells(fx, cells, 3 + (fx.level or 0), 8 + (fx.level or 0))
            -- The landing and the roof are board facts; a dry run has no board to land on.
            local combat = fx.combat
            if not (combat and combat.arena) then return end
            local ax, ay = landing(combat, u, cells)
            if ax then fx.teleportUser(ax, ay, { glide = true }) end
            local Combat = require("models.combat")
            local Hazard = require("models.hazard")
            local tiles = combat.arena.tiles
            local cand = {}
            for y = u.y - 3, u.y + (u.h or 1) + 2 do
                for x = u.x - 3, u.x + (u.w or 1) + 2 do
                    local cell = tiles[y] and tiles[y][x]
                    local gap = Combat.cellGap(x, y, u)
                    if cell and cell.walkable and gap >= 2 and gap <= 3 and #Hazard.allAt(combat, x, y) == 0 then
                        cand[#cand + 1] = { x = x, y = y }
                    end
                end
            end
            for _ = 1, math.min(ROOF, #cand) do
                local pick = table.remove(cand, fx.random(#cand))
                fx.placeHazard(pick.x, pick.y, "hazard_roof_falling", {})
            end
        end,
    },
}
