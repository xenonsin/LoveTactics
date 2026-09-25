-- CAVE-IN: delved too greedily and too deep (round 3, 2026-09-24, Keno's note "spawn lava tiles").
--
-- Delve (data/items/ability/ability_delve.lua) lands this on its caster when it surfaces holding its third
-- stack of Deeper. It is a STATUS rather than a line in the Delve's effect for one reason: an ability's
-- effect is dry-run for every forecast, and ground rewritten under the cursor would be a board that
-- changed because somebody hovered. A status's onApply only ever runs live.
--
-- On landing, every EMPTY tile orthogonally beside the surfacing dwarf turns to lava -- impassable, and
-- (like a river) no bar to a line of sight (models/terrain.lua). Whoever stands beside the exit keeps
-- their tile and may find it walled in; the delver has reshaped the room. A tile holding a zone (a coin
-- heap, a banner's ground) is left alone, so gold is never sealed under rock. The cell is rewritten from
-- the terrain table, as Combat.floodTile rewrites a ford, so every reader downstream sees real lava.
--
-- The status itself is a badge for a beat and nothing more.
return {
    name = "Cave-In",
    abbr = "Cave",
    description = "Delved too deep: the ground beside it has turned to lava.",
    color = { 0.720, 0.280, 0.120 }, -- badge tint (lava)
    duration = 1,
    hideDuration = true,
    onApply = function(ctx)
        local combat, unit = ctx.combat, ctx.unit
        local tiles = combat and combat.arena and combat.arena.tiles
        if not (tiles and unit) then return end
        local Combat = require("models.combat")
        local Hazard = require("models.hazard")
        local lava = require("models.terrain").get("lava")
        local turned = 0
        for _, d in ipairs({ { 0, -1 }, { 1, 0 }, { 0, 1 }, { -1, 0 } }) do
            local x, y = unit.x + d[1], unit.y + d[2]
            local cell = tiles[y] and tiles[y][x]
            if cell and cell.walkable and not Combat.unitAt(combat, x, y)
                and not Combat.objectAt(combat, x, y) and #Hazard.allAt(combat, x, y) == 0 then
                cell.type = "lava"
                cell.moveCost = lava.moveCost
                cell.walkable = lava.walkable
                cell.sightCost = lava.sightCost or 0
                cell.bonus = lava.bonus
                cell.tags = lava.tags
                cell.swim, cell.drowns = nil, nil
                turned = turned + 1
            end
        end
        if turned > 0 then
            ctx.log("action", string.format("%s has delved too deep: the floor beside it runs molten.",
                (unit.char and unit.char.name) or "It"), unit)
        end
    end,
}
