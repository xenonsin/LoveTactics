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

-- DOES WALKING ONTO THIS STOP START A FIGHT? One question, asked from two places that must never
-- disagree: states/game.lua opens the arena on it, and ui/overworld_map.lua draws the combat border on
-- it. A marker that promises a fight the state then does not run is a lie the player only finds out by
-- walking there, and two copies of a four-clause test is exactly how that lie gets authored.
--
-- Takes the CELL'S encounter -- the plain table the board serializes -- rather than a blueprint, because
-- that is what both callers hold. Kind alone does not answer it, and the two exceptions are the reason
-- this is a function:
--
--   a PACK is a fight only when something is standing on it. A pile dropped before the guard rule
--   existed is a pickup, and it falls through to the unconditional collect at the bottom of
--   game:openEncounter.
--
--   an OBJECTIVE is a fight unless it is a `meet` -- a walk-out rather than a battle (the arena debut,
--   data/quests/colosseum/quest_colosseum_slot_01.lua). The flag rides the cell because the draw layer
--   has no objective spec to consult; models/overworld.lua copies it across at placement.
--
-- Deliberately NOT keyed on the marker kind the map derives (`quest`, for an errand): that split is a
-- question about which glyph to draw, and an errand is an `objective` to everything else in the stack.
-- The state's battle branch matches it here for free, which is the whole point.
function Encounter.opensBattle(enc)
    if not enc then return false end
    if enc.kind == "combat" or enc.kind == "elite" then return true end
    if enc.kind == "objective" then return not enc.meet end
    if enc.kind == "pack" then return enc.composition ~= nil end
    return false
end

-- Is `def` eligible in this context? Gated by minPrestige and an optional
-- condition(ctx) predicate on the blueprint.
local function eligible(def, ctx)
    -- Gated on the DAY rather than on the company's standing: an encounter that "only turns up once the
    -- player has some renown" is really about how deep into the campaign the road is, and under the
    -- calendar that is what the day measures (models/calendar.lua).
    if def.minDay and (ctx.day or 1) < def.minDay then return false end
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

    -- ORDERED BY ID, and this is what makes a seeded board a seeded board.
    --
    -- The generator draws its stops out of this pool in LIST order (models/overworld.lua), and the list
    -- was assembled by walking a keyed table with `pairs` -- which Lua leaves unspecified. So the same
    -- seed laid a different floor on another machine, or after a Lua build changed how it hashes a
    -- string, and the seed the whole mode reproduces from was quietly a half-truth: same circles, same
    -- houses, different ground. Descent.HAZARDS is written as an ordered list for exactly this reason;
    -- this is the same rule applied where the ids come out of a table instead of a literal.
    --
    -- By id rather than by weight or name: an id is unique, so no two entries can tie and be left in
    -- whatever order they arrived in, which would put the bug straight back.
    table.sort(pool, function(a, b) return a.id < b.id end)
    return pool
end

return Encounter
