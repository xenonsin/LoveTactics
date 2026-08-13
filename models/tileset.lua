-- Tileset resolution. Each biome names a tileset (data/tilesets/<id>.lua) that
-- supplies the *art*: a spritesheet `image`, its `tileSize`, and per-type sheet
-- `index` / fallback `color`. The tile *types and their walkability* are universal
-- (a path is walkable in any biome), so they live here and are merged into every
-- tileset. models/overworld.lua reads the merged def for walkability; the renderer
-- ui/overworld_map.lua reads it for the sheet + quads — so the two can never
-- disagree. Plain data + love.filesystem, so it is safe under the headless tests.
--
--   local def = require("models.tileset").get(biome.tileset)
--   def.image / def.tileSize / def.tiles[type].{index,walkable,color}

local Registry = require("models.registry")
local Terrain = require("models.terrain") -- the one terrain table, shared with the battle board

local Tileset = {}

-- Canonical tile types: walkability plus the default 1-based sheet index and a pre-art fallback colour.
-- A biome tileset may override `index`/`color` per type; behaviour is fixed.
--
-- READ OFF models/terrain.lua RATHER THAN DECLARED HERE, because the map and the board are the same
-- ground now (docs/overworld.md, one map): a fight is fought on an 8x8 window of these very tiles, so a
-- second opinion about whether one is walkable would be a second opinion about the battlefield. This
-- table used to hold six types and one fact about each; it is now a view of every type there is.
Tileset.TYPES = Terrain.tilesetTypes()

Tileset.defs = Registry.load("data/tilesets", "data.tilesets")

-- Fallback art for an unknown / tileset-less biome.
local DEFAULT = { image = "assets/overworld/tileset.png", tileSize = 16 }

local cache = {}

-- Merge the canonical types with a biome tileset's art into a full descriptor:
--   { image, tileSize, tiles = { <type> = { index, walkable, color } } }
local function build(def)
    def = def or DEFAULT
    local tiles = {}
    for name, base in pairs(Tileset.TYPES) do
        local over = def.tiles and def.tiles[name]
        tiles[name] = {
            index = (over and over.index) or base.index,
            walkable = base.walkable, -- universal, never overridden by a biome
            color = (over and over.color) or base.color,
        }
    end
    return {
        image = def.image or DEFAULT.image,
        tileSize = def.tileSize or DEFAULT.tileSize,
        tiles = tiles,
    }
end

-- Resolve (and memoize) the full tileset descriptor for a tileset id. An unknown
-- or nil id falls back to DEFAULT art, so generation/rendering never breaks.
function Tileset.get(id)
    local key = id or "__default"
    if not cache[key] then
        cache[key] = build(Tileset.defs[id])
    end
    return cache[key]
end

return Tileset
