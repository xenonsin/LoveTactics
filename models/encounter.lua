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
    -- PARKED (2026-09-17). A blueprint that is still on disk but must never be rolled says so here, and
    -- this is the whole of the parking: no weight to zero, no id struck from a list somewhere else. The
    -- three relic stops -- the Reliquary, the Sin's Altar and the Weeping Stone -- wear it, because
    -- models/relic.lua is parked and those are the stops whose only payload was a relic. Read
    -- `Relic.PARKED`'s note before lifting any of them.
    --
    -- Checked FIRST and before the day gate so the answer does not depend on the context: a parked
    -- encounter is ineligible everywhere, including in a spec that hands this an empty ctx.
    if def.parked then return false end
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

-- ---------------------------------------------------------------------------
-- What a stop IS, in words
-- ---------------------------------------------------------------------------

-- WHAT THE MARK SAYS, which is not always what the encounter IS.
--
-- Lived in ui/overworld_map.lua while it was a question about drawing and nothing else -- a board
-- carries as many ends as the day has work in it and every one is stamped `objective` because to the
-- arena's cap, the salvage and the payout they are one thing, so splitting the KIND in the model would
-- quietly stop a dozen `kind == "objective"` tests from matching an errand. That argument still holds
-- for the MODEL'S kind; what changed is that the split is no longer about drawing alone. The hover
-- readout names the same three things the marker draws (ui/encounter_tooltip.lua) and has to call them
-- what the plate calls them, so two copies of this would be two surfaces disagreeing about which tile
-- holds the boss.
--
-- The discriminators both ride the cell's encounter: a spec belonging to a piece of posted work carries
-- that work's id (`questId`) and the board's own end carries nothing, and a circle that bars its stair
-- with a body (Descent.GATES' `ward`) stamps `wardFor` on the lieutenant standing in front of it. The
-- ward is asked FIRST: it is an `objective` like every other end, so the clause below would swallow it.
function Encounter.markerKind(enc)
    if enc and enc.wardFor then return "ward" end
    if enc and enc.kind == "objective" and enc.questId then return "quest" end
    return enc and enc.kind
end

-- EVERY KIND A CELL CAN CARRY, declared rather than derived, because half of them are minted by a
-- generator and never appear in data/encounters at all -- the way down and the way up, the hole in the
-- floor, the day's ends, the pack a dead company left. A derived set would report full coverage of the
-- blueprints and say nothing about the six kinds a player meets most.
--
-- Two of the entries are the marker splits above rather than model kinds (`quest`, `ward`); they are
-- here because this list is what the gloss is measured against and the gloss is read through
-- Encounter.markerKind. Kept in step with the blueprints by tests/encounter_gloss_spec.lua, which walks
-- `Encounter.defs` and fails on a kind that reached disk without a sentence.
Encounter.MARKER_KINDS = {
    "combat", "elite", "pack", "objective", "quest", "ward",
    "treasure", "rest", "town", "merchant", "crossroads", "event",
    "relic_cache", "shrine", "weeping_stone", "anvil", "translation",
    "spinner", "dark", "drop", "stair", "ascent",
}

-- ONE SENTENCE PER KIND OF STOP, read by every surface that has to say what walking there does: the
-- hover readout over the map (ui/encounter_tooltip.lua) and the modal the step opens
-- (ui/panels/encounter.lua). Six of these were the panel's own private table and the map had none at
-- all, so a board whose whole vocabulary is a colour and a fourteen-pixel mark could be read only by
-- walking onto things -- and the two surfaces that did speak were one edit from disagreeing.
--
-- WHAT A LINE SAYS IS WHAT THE MARK CANNOT. A shape can say "anvil" and not "it will temper one piece
-- you are carrying, for nothing"; a colour can say "this is not a fight" and not which way the stair
-- goes. So each is the generic account of the STOP -- flat, present tense, the register every other
-- piece of interface copy is written in -- and the per-placement specifics (its tier, how it stands
-- against the company, what it salvages, what a house pays for it) ride under it as figures, off the
-- live cell, never retyped here.
Encounter.GLOSS = {
    combat        = "Hostiles hold the trail. Walking here starts the fight.",
    elite         = "A tougher body than the rank and file. Worth more, and it hits back.",
    pack          = "The pack your company dropped when it fell. Walk here to carry it out.",
    objective     = "The floor's own end. Put it down and the stair opens.",
    quest         = "Work a house posted. Take it and the shelf it belongs to opens wider.",
    ward          = "A lieutenant set in front of the stair. The gate holds until she falls.",
    treasure      = "An unguarded cache. Nothing stands over it; it is simply picked up.",
    rest          = "A safe camp. Rest here and the company takes some of the road back.",
    town          = "A waystation. Rest, resupply, and move on.",
    merchant      = "A market on the road. Goods off this floor's shelf, for gold.",
    crossroads    = "A dilemma with real stakes. It is rolled fresh, and it is a gamble.",
    event         = "Something happens here. No fight, and no way to know it in advance.",
    relic_cache   = "A reliquary. Something rare is sealed inside it.",
    shrine        = "An altar that trades. It wants gold up front, and what it gives back bites.",
    weeping_stone = "A stone that deals in rare goods and charges a body for them.",
    anvil         = "A cold forge. One piece you are carrying is tempered here, for nothing.",
    translation   = "The ground moves under you. A step onto it puts the company somewhere else.",
    spinner       = "The ground turns you. A step onto it sends the next one the wrong way.",
    dark          = "Blind ground. The company sees no further than the tile it stands on.",
    drop          = "A hole through the floor. It goes down without the stair, and you are asked first.",
    stair         = "The way down to the next circle.",
    ascent        = "The way back up. The trip ends here, and what you are carrying comes with you.",
}

-- The sentence for `enc`, or nil for a stop with no kind at all. Read through Encounter.markerKind, so
-- an end, a house's errand and a ward are told apart here exactly as the plate tells them apart.
--
-- A kind with no line falls through to NIL rather than to a generic one: a readout that says "something
-- is here" under a mark that already says something is here is a row spent saying nothing, and a
-- missing sentence should be visibly missing rather than papered over (tests/encounter_gloss_spec.lua).
function Encounter.gloss(enc)
    local kind = Encounter.markerKind(enc)
    return kind and Encounter.GLOSS[kind] or nil
end

return Encounter
