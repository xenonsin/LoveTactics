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

-- The signature ground a generated battle board seeds for this biome, or nil when it has none.
-- A blueprint declares it as `hazard = { id = "hazard_quicksand", min = 1, max = 2, duration = 20 }`;
-- models/arena.lua's generateLayout rolls that many patches onto open ground.
--
-- Normalized here rather than at the call site so a blueprint can say just `{ id = ... }` and get one
-- patch, and so a def that names no hazard reads as nil rather than as an empty spec the generator has
-- to test twice. Returns nil for a hazard with no id, so a half-written blueprint seeds nothing instead
-- of seeding garbage Combat.new would have to reject.
function Biome.hazardFor(id)
    local spec = Biome.get(id).hazard
    if not (spec and spec.id) then return nil end
    local min = spec.min or 1
    local max = spec.max or min
    if max < min then max = min end
    return { id = spec.id, min = min, max = max, duration = spec.duration }
end

return Biome
