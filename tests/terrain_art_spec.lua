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
local Tileset = require("models.tileset")

-- Every biome that has a tileset, so the skin cases below walk the real set rather than a list here
-- that would fall behind the day a ninth ground landed.
local function tilesetIds()
    local out = {}
    for id in pairs(Tileset.defs) do out[#out + 1] = id end
    table.sort(out)
    return out
end

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
    {
        -- A biome may lend a type a different PICTURE and different WORDS (models/tileset.lua's
        -- `skin`/`name`/`desc`): the castle's `mountain` is a rampart of set stone, the colosseum's a
        -- pillar. A skin naming a mark that has been deleted or renamed draws NOTHING and says so
        -- nowhere -- TerrainArt.markFor falls back to the terrain's own mark on purpose, so the board
        -- would quietly go back to putting a snow-capped peak inside a fortress and look fine.
        name = "every skin a tileset names is a mark that exists, and every mark has a taker",
        fn = function()
            local named = {}
            local bad = {}
            for _, id in ipairs(tilesetIds()) do
                local def = Tileset.get(id)
                for _, kind in ipairs(sortedKeys(def.tiles)) do
                    local skin = def.tiles[kind].skin
                    if skin then
                        named[skin] = true
                        if not TerrainArt.SKINS[skin] then
                            bad[#bad + 1] = id .. "." .. kind .. " -> " .. skin
                        end
                    end
                end
            end
            assert(#bad == 0, "tileset names a mark that does not exist: " .. table.concat(bad, ", "))

            -- ...and the other direction. A skin nobody asks for is dead art, and dead art in a file
            -- whose whole contract is "one mark per type" is how the masonry got deleted in the first
            -- place: it was orphaned by a rename and there was no case that could see it.
            local orphans = {}
            for _, skin in ipairs(sortedKeys(TerrainArt.SKINS)) do
                if not named[skin] then orphans[#orphans + 1] = skin end
            end
            assert(#orphans == 0, "no tileset uses the skin: " .. table.concat(orphans, ", "))

            -- A skin id may never collide with a terrain type, or markFor's override would silently
            -- shadow a real tile's own mark everywhere the skin is named.
            for _, skin in ipairs(sortedKeys(TerrainArt.SKINS)) do
                assert(not Terrain.TYPES[skin], skin .. " is both a skin and a terrain type")
            end
        end,
    },
    {
        -- What the skin may NOT do. A biome dresses the ground; it does not re-rule it, and the one
        -- way that promise could break quietly is a tileset entry growing a `walkable`, a `moveCost`
        -- or a `sightCost` that some future reader starts honouring.
        name = "a reskinned tile keeps every rule the terrain table gave it",
        fn = function()
            for _, id in ipairs(tilesetIds()) do
                local def = Tileset.get(id)
                for _, kind in ipairs(sortedKeys(def.tiles)) do
                    local tile = def.tiles[kind]
                    assert(tile.walkable == Terrain.TYPES[kind].walkable,
                        id .. " re-rules " .. kind .. "'s walkability")
                    assert(tile.moveCost == nil and tile.sightCost == nil,
                        id .. " tries to re-price " .. kind)
                end
            end
        end,
    },
    {
        -- The heading and the swatch have to move TOGETHER. A box that draws set stone over the word
        -- "Mountain", or says "Rampart" over a snow-capped peak, is worse than either alone: the
        -- tooltip is the one surface where the mark is taught beside its name, so a pair that
        -- disagrees teaches the wrong picture for the word.
        name = "a biome's own word for a tile arrives with the biome's own mark",
        fn = function()
            local cell = { type = "mountain", walkable = false, moveCost = math.huge,
                           sightCost = math.huge }
            local skin = Tileset.get("castle").tiles.mountain
            assert(skin.skin == "masonry" and skin.name == "Rampart",
                "the castle is supposed to be the case this is asserted on")

            local blocks = TileTooltip.blocks({ cell = cell, tone = { 0.3, 0.3, 0.34 }, skin = skin })
            local head, desc
            for _, blk in ipairs(blocks) do
                if blk.kind == "title" and not head then head = blk end
                if blk.kind == "desc" and not desc then desc = blk end
            end
            assert(head and head.text == "Rampart", "the castle names its own solid")
            assert(head.skin == "masonry", "...and hands the swatch the mark the board is drawing")
            assert(desc and desc.text == skin.desc, "the biome's sentence rides with its name")

            -- No skin, and the terrain answers for itself again -- both fields, not just the one.
            local plain = TileTooltip.blocks({ cell = cell, tone = { 0.3, 0.3, 0.34 } })
            local ph
            for _, blk in ipairs(plain) do if blk.kind == "title" then ph = blk break end end
            assert(ph and ph.text == "Mountain" and ph.skin == nil,
                "open country calls the same tile a mountain and draws the peak")
        end,
    },
}
