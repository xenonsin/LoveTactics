-- Every terrain has a mark, every mark has a terrain, and every terrain has a NAME (ui/terrain_art.lua,
-- ui/tile_tooltip.lua).
--
-- A missing mark fails silently and expensively. TerrainArt.draw returns without drawing for a type it
-- does not know -- deliberately, because a wrong picture on the ground is worse than a plain tile --
-- so a terrain added to models/terrain.lua without a mark does not crash, it just goes back to being
-- a flat rectangle of the biome's colour. Which is the exact fault the marks were drawn to fix, and
-- the board would look merely slightly duller rather than broken. Same for the tooltip: a type with no
-- TILE_INFO row falls back to its title-cased id and an empty description, so the ONE surface where
-- the mark is taught beside its name would quietly stop teaching it.
--
-- Pure table lookups, so it runs headless: ui/terrain_art.lua touches love.graphics only inside a mark,
-- and ui/tile_tooltip.lua only inside its draw.

local Terrain = require("models.terrain")
local TerrainArt = require("ui.terrain_art")
local TileTooltip = require("ui.tile_tooltip")
local BattleMap = require("ui.battle_map")

local function sortedKeys(t)
    local out = {}
    for k in pairs(t) do out[#out + 1] = k end
    table.sort(out)
    return out
end

return {
    {
        name = "every terrain type has a mark",
        fn = function()
            local missing = {}
            for _, name in ipairs(sortedKeys(Terrain.TYPES)) do
                if not TerrainArt.MARKS[name] then missing[#missing + 1] = name end
            end
            assert(#missing == 0, "no mark for: " .. table.concat(missing, ", "))
        end,
    },
    {
        name = "every mark belongs to a real terrain type",
        fn = function()
            local orphans = {}
            for _, name in ipairs(sortedKeys(TerrainArt.MARKS)) do
                if not Terrain.TYPES[name] then orphans[#orphans + 1] = name end
            end
            assert(#orphans == 0, "mark for no such terrain: " .. table.concat(orphans, ", "))
        end,
    },
    {
        name = "every terrain type has an art role, so no floor draws as the trail by accident",
        fn = function()
            -- The `or "path"` at the draw site keeps a missing entry from crashing, and that is the
            -- danger: a desert's sand painted in the trail's colour is indistinguishable from open
            -- ground, and now that the mark carries identity the colour collision is easy to miss.
            local missing = {}
            for _, name in ipairs(sortedKeys(Terrain.TYPES)) do
                if not BattleMap.ART[name] then missing[#missing + 1] = name end
            end
            assert(#missing == 0, "no art role for: " .. table.concat(missing, ", "))
        end,
    },
    {
        name = "every terrain type is named and described where its mark is taught",
        fn = function()
            -- Asked of the authored table itself, not of the built blocks. The fallback title-cases
            -- the id, so a type that was never written down answers "Bridge" for `bridge` exactly as
            -- an authored row does -- read off the blocks, six real entries look identical to six
            -- holes, and the check that first stood here flagged all six of them.
            local bad = {}
            for _, name in ipairs(sortedKeys(Terrain.TYPES)) do
                local meta = TileTooltip.TERRAIN[name]
                if not meta then bad[#bad + 1] = name .. " (not named)"
                elseif not meta.name or meta.name == "" then bad[#bad + 1] = name .. " (no name)"
                elseif not meta.desc or meta.desc == "" then bad[#bad + 1] = name .. " (no description)" end
            end
            assert(#bad == 0, "unnamed terrain: " .. table.concat(bad, ", "))
        end,
    },
    {
        name = "a terrain heading carries its mark exactly when the caller supplies a ground tone",
        fn = function()
            -- The swatch is the whole of the teaching, so it has to appear whenever the board is
            -- drawing marks (BattleMap:tileTone answers a tone) and never when it is drawing a real
            -- tileset sheet (tileTone answers nil, and the picture beside the name would be one the
            -- ground is not showing).
            local cell = { type = "forest", walkable = true, moveCost = 2, sightCost = 1 }
            local withTone = TileTooltip.blocks({ cell = cell, tone = { 0.2, 0.4, 0.2 } })
            local without = TileTooltip.blocks({ cell = cell })
            local a, b
            for _, blk in ipairs(withTone) do if blk.kind == "title" then a = blk break end end
            for _, blk in ipairs(without) do if blk.kind == "title" then b = blk break end end
            assert(a and a.swatch == "forest", "a tile with a tone should teach its mark")
            assert(b and b.swatch == nil, "a tile with no tone should carry no swatch")
        end,
    },
}
