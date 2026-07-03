-- Encounter logic. Blueprints live in data/encounters/<id>.lua. Selection is
-- dynamic: `Encounter.pool(ctx)` returns the encounters eligible for a context
-- (player prestige + biome/quest conditionals), each with a resolved numeric
-- weight, ready for weighted random placement by the overworld generator.
--
--   local pool = Encounter.pool({ prestige = 2, biome = "forest", quest = q })
--   -- pool = { { id, kind, name, weight }, ... }

local Registry = require("models.registry")

local Encounter = {}

Encounter.defs = Registry.load("data/encounters", "data.encounters")

function Encounter.get(id) return Encounter.defs[id] end

-- Is `def` eligible in this context? Gated by minPrestige and an optional
-- condition(ctx) predicate on the blueprint.
local function eligible(def, ctx)
    if def.minPrestige and (ctx.prestige or 1) < def.minPrestige then return false end
    if def.condition and not def.condition(ctx) then return false end
    return true
end

-- Resolve a blueprint's weight, which may be a number or a function(ctx).
local function weightOf(def, ctx)
    local w = def.weight or 1
    if type(w) == "function" then w = w(ctx) end
    return w or 0
end

-- Eligible encounters for `ctx`, as { id, kind, name, weight } entries (weight
-- > 0). Order is not guaranteed (keyed off the registry).
function Encounter.pool(ctx)
    ctx = ctx or {}
    local pool = {}
    for id, def in pairs(Encounter.defs) do
        if eligible(def, ctx) then
            local w = weightOf(def, ctx)
            if w > 0 then
                pool[#pool + 1] = { id = id, kind = def.kind, name = def.name, weight = w }
            end
        end
    end
    return pool
end

return Encounter
