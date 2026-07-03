-- Biome logic. Blueprints live in data/biomes/<id>.lua and are auto-discovered
-- by the registry. A biome drives overworld generation knobs (currently the
-- maze `spacing`); models/overworld.lua reads it via Biome.get.

local Registry = require("models.registry")

local Biome = {}

Biome.defs = Registry.load("data/biomes", "data.biomes")

local DEFAULT = { name = "Forest", tileset = "forest", spacing = 4, rivers = 1 }

-- Return the biome def for `id`, falling back to forest / a safe default so an
-- unknown or missing biome never breaks generation.
function Biome.get(id)
    return (id and Biome.defs[id]) or Biome.defs.forest or DEFAULT
end

return Biome
