-- Tests for the biome layer: the four floors added alongside forest/castle/underworld
-- (data/biomes/*.lua), the battle-board terrain each one scatters (Arena.BIOME_TERRAIN /
-- Arena.TILE_PROPS), and the signature hazard a generated board seeds for it (Biome.hazardFor).
--
-- The load-bearing property here is that NONE of this shifted a seeded draw: boards generated before
-- the biome palette existed must still generate identically, because a quest's map is reproduced from
-- its stored seed. That is what the "unchanged" cases below pin.

local Arena = require("models.arena")
local Biome = require("models.biome")
local Overworld = require("models.overworld")
local Tileset = require("models.tileset")

local NEW_BIOMES = { "desert", "tundra", "volcanic", "swamp" }

-- Flatten a generated arena layout's tiles to a comparable string.
local function tileSignature(layout)
    local parts = {}
    for y = 1, layout.rows do
        for x = 1, layout.cols do
            parts[#parts + 1] = layout.tiles[y][x]
        end
    end
    return table.concat(parts, ",")
end

return {
    {
        name = "every new biome has a blueprint, a tileset, and a signature hazard",
        fn = function()
            for _, id in ipairs(NEW_BIOMES) do
                local def = Biome.defs[id]
                assert(def, "no data/biomes/" .. id .. ".lua")
                assert(def.name and def.name ~= "", id .. " has no display name")
                assert(def.tileset, id .. " names no tileset")
                assert(Tileset.defs[def.tileset], id .. " names a missing tileset: " .. tostring(def.tileset))
                assert(Biome.hazardFor(id), id .. " declares no signature hazard")
            end
        end,
    },
    {
        name = "a biome's signature hazard names a real hazard blueprint",
        fn = function()
            local Registry = require("models.registry")
            local hazards = Registry.load("data/hazards", "data.hazards")
            for _, id in ipairs(NEW_BIOMES) do
                local spec = Biome.hazardFor(id)
                assert(hazards[spec.id], id .. " seeds an unknown hazard: " .. tostring(spec.id))
            end
        end,
    },
    {
        name = "hazardFor normalizes a bare spec and rejects one with no id",
        fn = function()
            -- min defaults to 1, max follows min, and an inverted range is corrected rather than
            -- producing an empty rng range at generation time.
            local saved = Biome.defs.__spec_probe
            Biome.defs.__spec_probe = { name = "Probe", hazard = { id = "hazard_fire" } }
            local spec = Biome.hazardFor("__spec_probe")
            assert(spec.min == 1 and spec.max == 1, "bare spec should normalize to exactly one patch")

            Biome.defs.__spec_probe = { name = "Probe", hazard = { id = "hazard_fire", min = 3, max = 1 } }
            spec = Biome.hazardFor("__spec_probe")
            assert(spec.max >= spec.min, "an inverted range must be corrected")

            Biome.defs.__spec_probe = { name = "Probe", hazard = { min = 2 } }
            assert(Biome.hazardFor("__spec_probe") == nil, "a hazard with no id must seed nothing")

            Biome.defs.__spec_probe = saved
        end,
    },
    {
        name = "biomes that shipped before the palette seed no hazard",
        fn = function()
            for _, id in ipairs({ "forest", "castle", "underworld" }) do
                assert(Biome.hazardFor(id) == nil, id .. " should not have gained a signature hazard")
            end
        end,
    },
    {
        name = "every terrain a biome scatters is a real tile with real properties",
        fn = function()
            for biome, palette in pairs(Arena.BIOME_TERRAIN) do
                for _, role in ipairs({ "fill", "rise", "block" }) do
                    local t = palette[role]
                    assert(t, biome .. " palette has no " .. role)
                    assert(Arena.TILE_PROPS[t], biome .. "'s " .. role .. " is not in TILE_PROPS: " .. tostring(t))
                end
            end
        end,
    },
    {
        name = "a generated board scatters its own biome's terrain",
        fn = function()
            -- The desert lays sand where the default lays forest. Same seed, so any difference is the
            -- palette rather than the draws.
            local plain = Arena.generateLayout({ seed = 99, party = 2, enemies = 2 })
            local desert = Arena.generateLayout({ seed = 99, party = 2, enemies = 2, biome = "desert" })

            local function has(layout, tile)
                for y = 1, layout.rows do
                    for x = 1, layout.cols do
                        if layout.tiles[y][x] == tile then return true end
                    end
                end
                return false
            end

            assert(has(plain, "forest"), "the default palette should still scatter forest")
            assert(has(desert, "sand"), "a desert board should scatter sand")
            assert(not has(desert, "forest"), "a desert board should scatter no forest at all")
        end,
    },
    {
        name = "the biome palette did not move a single seeded draw",
        fn = function()
            -- An unknown biome falls back to the default palette, so its board must be tile-for-tile
            -- what a biome-less board is -- which is what every arena generated before this change was.
            local before = Arena.generateLayout({ seed = 4242, party = 3, enemies = 3 })
            local after = Arena.generateLayout({ seed = 4242, party = 3, enemies = 3, biome = "__unknown__" })
            assert(tileSignature(before) == tileSignature(after),
                "an unknown biome must reproduce the pre-palette board exactly")
        end,
    },
    {
        name = "a biome board seeds its hazard onto standable ground",
        fn = function()
            local layout = Arena.generateLayout({ seed = 7, party = 2, enemies = 2, biome = "desert" })
            assert(#layout.hazards >= 1, "a desert board should seed at least one quicksand patch")
            for _, h in ipairs(layout.hazards) do
                assert(h.id == "hazard_quicksand", "the desert seeds quicksand, got " .. tostring(h.id))
                local props = Arena.TILE_PROPS[layout.tiles[h.y][h.x]] or {}
                assert(props.walkable, "a seeded hazard must sit on a tile a unit can stand on")
            end
        end,
    },
    {
        name = "a biome with no signature hazard seeds none",
        fn = function()
            local layout = Arena.generateLayout({ seed = 7, party = 2, enemies = 2, biome = "forest" })
            assert(#layout.hazards == 0, "the forest should seed no hazards")
        end,
    },
    {
        name = "lava blocks the tile but not the shot; every other new floor is standable",
        fn = function()
            local lava = Arena.TILE_PROPS.lava
            assert(not lava.walkable, "lava must be impassable")
            assert(lava.sightCost == 0, "lava must NOT block line of sight -- that is the whole point of it")
            assert(Arena.TILE_PROPS.obstacle.sightCost > 0, "an obstacle should still block sight")

            for _, t in ipairs({ "sand", "ice", "mire" }) do
                assert(Arena.TILE_PROPS[t].walkable, t .. " must be walkable")
                assert(Arena.TILE_PROPS[t].sightCost == 0, t .. " grants no cover by design")
            end
        end,
    },
    {
        name = "ice is the one terrain feature that does not tax a step; the rest do",
        fn = function()
            local ground = Arena.TILE_PROPS.ground.moveCost
            -- Not CHEAPER than open field -- there is no such cost short of 0, which would mean
            -- unlimited movement across it. Ice is free in the sense that matters: alone among terrain
            -- features it charges nothing extra, so a board scattered with it has no movement obstacles.
            assert(Arena.TILE_PROPS.ice.moveCost == ground, "ice must cost exactly what open field costs")
            for _, t in ipairs({ "forest", "water", "mountain", "rough", "sand", "mire" }) do
                assert(Arena.TILE_PROPS[t].moveCost > ground, t .. " must cost more than open field")
            end
            -- Mire ties the mountain rather than beating it: a cost above 3 would make the scattered
            -- fill of a swamp board effectively impassable for ordinary move budgets, which is an
            -- obstacle wearing a floor's name. What makes it distinct is what it gives back, not its price.
            assert(Arena.TILE_PROPS.mire.moveCost == Arena.TILE_PROPS.mountain.moveCost,
                "mire should tie the mountain for the heaviest walkable floor")
            assert(Arena.TILE_PROPS.mountain.bonus, "the mountain is supposed to pay for its cost")
            assert(Arena.TILE_PROPS.mire.bonus == nil, "mire charges a mountain's price and grants nothing")
        end,
    },
    {
        name = "ice and mire conduct; sand does not",
        fn = function()
            local function hasTag(t, want)
                for _, tag in ipairs(Arena.TILE_PROPS[t].tags or {}) do
                    if tag == want then return true end
                end
                return false
            end
            assert(hasTag("ice", "conductable"), "frozen water still conducts")
            assert(hasTag("mire", "conductable"), "a bog is wet through")
            assert(not hasTag("sand", "conductable"), "dry sand must not conduct")
        end,
    },
    {
        name = "each new biome draws a distinct overworld map",
        fn = function()
            -- Same seed across biomes: spacing, rivers and the decorate thresholds must actually differ,
            -- or the biomes are a reskin rather than a place.
            local seen = {}
            for _, id in ipairs(NEW_BIOMES) do
                local grid = Overworld.generate({
                    seed = 31337, encounterCount = 4, keyCount = 1,
                    objective = { name = "Boss" }, biome = id,
                })
                local parts = {}
                for y = 1, grid.rows do
                    for x = 1, grid.cols do parts[#parts + 1] = grid:get(x, y).tile end
                end
                local sig = table.concat(parts, ",")
                for other, otherSig in pairs(seen) do
                    assert(sig ~= otherSig, id .. " draws the same map as " .. other)
                end
                seen[id] = sig
            end
        end,
    },
    {
        name = "every arena tile type maps to real biome art",
        fn = function()
            -- The draw site falls back to "path" for an unmapped type, so a missing entry never crashes
            -- -- it silently paints that floor as the trail, which on a desert board makes sand and open
            -- ground identical. That is the failure this pins.
            local BattleMap = require("ui.battle_map")
            for tile in pairs(Arena.TILE_PROPS) do
                local artType = BattleMap.ART[tile]
                assert(artType, "arena tile '" .. tile .. "' has no ART mapping; it would draw as trail")
                assert(Tileset.TYPES[artType],
                    "arena tile '" .. tile .. "' maps to a non-existent overworld role: " .. tostring(artType))
            end
        end,
    },
    {
        name = "costly floors are washed; free and unwalkable ones are not",
        fn = function()
            local BattleMap = require("ui.battle_map")
            for tile, props in pairs(Arena.TILE_PROPS) do
                local tint = BattleMap.TERRAIN_TINT[tile]
                if props.walkable and props.moveCost > Arena.TILE_PROPS.ground.moveCost then
                    assert(tint, tile .. " costs more than open field and must read as costly")
                else
                    assert(not tint, tile .. " charges nothing extra, so it must not promise a penalty")
                end
            end
        end,
    },
    {
        name = "every quest names a biome that exists",
        fn = function()
            local Quest = require("models.quest")
            for id, def in pairs(Quest.defs) do
                local biome = def.map and def.map.biome
                assert(biome, id .. " names no biome")
                assert(Biome.defs[biome], id .. " names an unknown biome: " .. tostring(biome))
                -- An inline follow-up leg (a scripted walk after the bout) carries its own map, and it
                -- is easy to retune the outer one and leave this behind on the biome it used to be.
                local follow = def.followUp and def.followUp.map and def.followUp.map.biome
                if follow then
                    assert(Biome.defs[follow], id .. "'s followUp names an unknown biome: " .. tostring(follow))
                end
            end
        end,
    },
    {
        name = "no sponsor's line runs entirely on one biome",
        fn = function()
            -- The Colosseum was 13/13 castle and the Lodge 13/13 forest before the biome pass; a line
            -- that never changes ground is the monotony this whole layer exists to fix.
            local Quest = require("models.quest")
            local byLine = {}
            for _, def in pairs(Quest.defs) do
                local sponsor = def.sponsor
                local biome = def.map and def.map.biome
                if sponsor and biome then
                    byLine[sponsor] = byLine[sponsor] or {}
                    byLine[sponsor][biome] = true
                end
            end
            for sponsor, biomes in pairs(byLine) do
                local n = 0
                for _ in pairs(biomes) do n = n + 1 end
                assert(n >= 3, sponsor .. " runs on only " .. n .. " biome(s); a line wants variety")
            end
        end,
    },
    {
        name = "every biome is somewhere in the campaign",
        fn = function()
            -- A biome nothing uses is dead weight carrying an art debt: 6 tiles nobody will ever see.
            local Quest = require("models.quest")
            local used = {}
            for _, def in pairs(Quest.defs) do
                local biome = def.map and def.map.biome
                if biome then used[biome] = (used[biome] or 0) + 1 end
            end
            for id in pairs(Biome.defs) do
                assert(used[id], "no quest is set in the " .. id .. " biome")
            end
        end,
    },
    {
        name = "every new tileset colours all six overworld roles",
        fn = function()
            for _, id in ipairs(NEW_BIOMES) do
                local def = Tileset.get(Biome.defs[id].tileset)
                for tile in pairs(Tileset.TYPES) do
                    local entry = def.tiles[tile]
                    assert(entry and entry.color, id .. " has no fallback colour for " .. tile)
                end
            end
        end,
    },
}
