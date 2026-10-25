-- THE DRESSING OF AN ORDINARY FIGHT: what makes the fortieth wolf pack on a floor not the thirty-ninth
-- (approved 2026-10-24, "variety in the fight itself"). Three systems, rolled together and stamped on the
-- cell's encounter so the map, the deploy screen and the fight agree:
--
--   affixes    one or two bodies carry a named twist (models/affix.lua)
--   objective  the fight wins on something besides kill-all: one of the objective pass's own shapes
--   condition  the weather or the ground it is fought in (models/condition.lua)
--
-- AT MOST TWO OF THE THREE on one fight. A fight with an affix, a clock AND fog is three things to read
-- before a turn is taken, and the point of all this is that each is read.
--
-- WHICH FIGHTS. Ordinary combats and elites on a descent floor, seated or wandering -- and nothing else:
-- never a stair (guardian, mini boss, general, the Crown -- none of them is a `combat`/`elite` cell), never
-- a fight whose blueprint already authors an `objective` or an escort, never an adventuring party (a party
-- is a company of classes whose objective-and-roster balance is measured on its own -- party_budget_spec --
-- and an affix on a cleric is a different budget), never a scripted stop (a lead-in, a ward, a posting or
-- an errand, anything that opens on a scene), never a sprung mimic or a guarded pack. Act 0 has no run,
-- so nothing on it is ever stamped (Descent.reseatElites returns before calling here).
--
-- DEALT OFF THE RUN'S SEED, THE FLOOR AND THE CELL, so a reload re-deals the same dressing to the same
-- fight, and the dressing is stamped once (`enc.dressing`, a plain table the save carries) and never
-- re-rolled on that encounter. A floor re-entered within the run re-seats its elites as fresh tables
-- (Overworld:reseatElites) and they are stamped again -- off the same seed and the same cell, so the
-- same answer.
--
-- THE OBJECTIVE IS STAMPED AS A KIND, AND MADE REAL AT THE BOARD. Only the board knows the roster (a
-- stop fields a band, rolled off the fight's seed), so the map promises "Defeat the leader" and
-- Arena.build names the leader (Dressing.materialize). The compatibility check at the map reads the
-- roster's centre; the board re-checks against the bodies actually dealt and falls back the same way.
--
-- Pure: no love.graphics, so it loads under the headless tests.
local Seed = require("models.seed")
local Affix = require("models.affix")
local Condition = require("models.condition")

local Dressing = {}

-- How often an eligible fight rolls an objective of its own. Affixes ride their own curve
-- (Affix.chanceAt) and conditions their own flat chance (Condition.CHANCE).
Dressing.OBJECTIVE_CHANCE = 0.30

-- THE ROLLED SHAPES, and their numbers are the authored ones, not new ones: a hold is the objective
-- pass's center hold at 25 ticks (data/encounters' holds run 20-30), a survive its 30-tick hold-out (30-40),
-- a reach its far edge with the endless tide Arena.normalizeObjective deals every reach and survive. Hold
-- and reach also take `orKillAll`, the pass's own "or clear them" clause, so clearing the field still
-- ends the fight -- an ordinary fight's roster was never written for a crossing.
Dressing.KINDS = { "assassinate", "break", "hold", "reach", "survive" }
Dressing.HOLD_TICKS = 25
Dressing.SURVIVE_TICKS = 30

-- The label the map and the tooltip use, in the objective vocabulary the HUD already speaks
-- (Combat.objectiveGoal): the map cannot name the body yet, so it names the job.
Dressing.KIND_LABEL = {
    assassinate = "Defeat the leader",
    ["break"] = "Break the totems",
    hold = "Hold the marked ground",
    reach = "Get anyone to the far side",
    survive = "Survive",
}

local SALT_AFFIX, SALT_OBJ, SALT_COND, SALT_CAP = 3301, 3307, 3313, 3319

-- ---------------------------------------------------------------------------
-- Eligibility
-- ---------------------------------------------------------------------------

function Dressing.eligible(enc)
    if type(enc) ~= "table" then return false end
    if enc.kind ~= "combat" and enc.kind ~= "elite" then return false end
    if enc.leadIn or enc.wardFor or enc.questId or enc.opening or enc.mimic or enc.ambush then return false end
    if enc.composition or enc.carried then return false end
    local def = enc.id and require("models.encounter").get(enc.id)
    if not def then return false end
    if def.objective or def.allies or def.party or def.scripted then return false end
    return true
end

-- ---------------------------------------------------------------------------
-- Rosters and the objective
-- ---------------------------------------------------------------------------

local function tierOf(id)
    local def = require("models.character").defs[id]
    return (def and def.tier) or 0
end

local function isObject(id)
    local def = require("models.character").defs[id]
    return def ~= nil and def.race == "object"
end

-- The leader of a roster: the single highest-tier body, or nil when the top tier is shared by DIFFERENT
-- bodies, or when there is nobody else in the fight (an assassination of the only body is a kill-all).
function Dressing.leaderOf(ids)
    local best, bestTier, tied = nil, -math.huge, false
    for _, id in ipairs(ids or {}) do
        if not isObject(id) then
            local t = tierOf(id)
            if t > bestTier then best, bestTier, tied = id, t, false
            elseif t == bestTier and id ~= best then tied = true end
        end
    end
    if not best or tied then return nil end
    local others = 0
    for _, id in ipairs(ids) do if id ~= best then others = others + 1 end end
    if others == 0 then return nil end
    return best
end

-- The objects a roster fields (a totem, a standard, an egg), distinct, in roster order.
function Dressing.objectsOf(ids)
    local out, seen = {}, {}
    for _, id in ipairs(ids or {}) do
        if isObject(id) and not seen[id] then seen[id] = true out[#out + 1] = id end
    end
    return out
end

local function fighters(ids)
    local n = 0
    for _, id in ipairs(ids or {}) do if not isObject(id) then n = n + 1 end end
    return n
end

-- Which rolled kinds `ids` can carry. A leader to assassinate needs one body standing above the rest; a
-- break needs something to break; the three ground-and-clock shapes need a line of at least two to make
-- a tide out of.
function Dressing.compatible(kind, ids)
    if kind == "assassinate" then return Dressing.leaderOf(ids) ~= nil end
    if kind == "break" then return #Dressing.objectsOf(ids) > 0 and fighters(ids) > 0 end
    if kind == "hold" or kind == "reach" or kind == "survive" then return fighters(ids) >= 2 end
    return false
end

-- The objective a rolled `kind` becomes against the roster actually dealt -- or nil, and the fight stays
-- a kill-all, if that roster cannot carry it. The same shapes the authored fights write.
function Dressing.materialize(kind, ids)
    if not (kind and Dressing.compatible(kind, ids)) then return nil end
    if kind == "assassinate" then
        -- `targets` rather than `target`: if the leader's blueprint is fielded twice, both fall.
        return { type = "assassinate", targets = { Dressing.leaderOf(ids) }, verb = "Defeat", rolled = true }
    elseif kind == "break" then
        return { type = "assassinate", targets = Dressing.objectsOf(ids), verb = "Break", rolled = true }
    elseif kind == "hold" then
        return { type = "hold", region = "center", duration = Dressing.HOLD_TICKS, orKillAll = true, rolled = true }
    elseif kind == "reach" then
        return { type = "reach", region = "far", orKillAll = true, rolled = true }
    elseif kind == "survive" then
        return { type = "survive", duration = Dressing.SURVIVE_TICKS, rolled = true }
    end
end

-- The roster's centre, for the map's compatibility check: the composition resolved with no seed (the
-- band's centre, as models/muster.lua rates it) and cut to the fight's tier.
function Dressing.rosterOf(enc, ctx)
    local def = enc and enc.id and require("models.encounter").get(enc.id)
    if not def then return {} end
    local Arena = require("models.arena")
    local c = {}
    for k, v in pairs(ctx or {}) do c[k] = v end
    c.encounterKind = enc.kind
    c.encounterCap = require("models.encounter").capOf(enc)
    c.seed = nil
    local ok, ids = pcall(Arena.resolveComposition, def.composition, c)
    if not ok or type(ids) ~= "table" then return {} end
    return Arena.clampComposition(ids, Arena.enemyCap(c))
end

-- ---------------------------------------------------------------------------
-- The roll
-- ---------------------------------------------------------------------------

local function unit(seed, floor, x, y, salt)
    return (Seed.mix(seed or 0, floor or 1, x or 0, y or 0, salt) % 1000000) / 1000000
end

local function pick(list, seed, floor, x, y, salt)
    if #list == 0 then return nil end
    return list[Seed.mix(seed or 0, floor or 1, x or 0, y or 0, salt) % #list + 1]
end

-- Roll a fight's dressing: { affixes = {ids}?, objective = kind?, condition = id? }, at most two of the
-- three. `ctx` is { seed, floor, x, y, biome } -- the run's seed, the depth, the cell.
function Dressing.roll(enc, ctx)
    ctx = ctx or {}
    local seed, floor, x, y = ctx.seed or 0, ctx.floor or 1, ctx.x or 0, ctx.y or 0
    local out = {}

    if unit(seed, floor, x, y, SALT_AFFIX) < Affix.chanceAt(floor) then
        local ids, picked = Affix.ids(), {}
        for k = 1, Affix.countAt(floor) do
            local id = table.remove(ids, Seed.mix(seed, floor, x, y, SALT_AFFIX + k) % #ids + 1)
            if id then picked[#picked + 1] = id end
        end
        if #picked > 0 then out.affixes = picked end
    end

    if unit(seed, floor, x, y, SALT_OBJ) < Dressing.OBJECTIVE_CHANCE then
        local roster = Dressing.rosterOf(enc, { depth = floor, biome = ctx.biome, rung = ctx.rung })
        local fits = {}
        for _, kind in ipairs(Dressing.KINDS) do
            if Dressing.compatible(kind, roster) then fits[#fits + 1] = kind end
        end
        out.objective = pick(fits, seed, floor, x, y, SALT_OBJ + 1)
    end

    if unit(seed, floor, x, y, SALT_COND) < Condition.CHANCE then
        out.condition = pick(Condition.ids(), seed, floor, x, y, SALT_COND + 1)
    end

    -- THE CAP: all three landed, so one is let go -- dealt off the same cell, so it is the same one on
    -- every reload.
    if out.affixes and out.objective and out.condition then
        local drop = Seed.mix(seed, floor, x, y, SALT_CAP) % 3
        if drop == 0 then out.affixes = nil
        elseif drop == 1 then out.objective = nil
        else out.condition = nil end
    end
    return out
end

-- Stamp `enc` (a cell's encounter table) with its dressing, once. Returns the dressing, or nil for a
-- fight that is not dressed at all.
function Dressing.stamp(enc, ctx)
    if not Dressing.eligible(enc) then return nil end
    if enc.dressing == nil then enc.dressing = Dressing.roll(enc, ctx) end
    return enc.dressing
end

-- Every eligible fight on a laid board, in one pass (Descent.reseatElites calls it on a fresh floor and
-- on a re-entered one). `ctx` is { seed, floor, biome }; each cell adds its own coordinates.
function Dressing.floor(grid, ctx)
    if not (grid and grid.cells) then return 0 end
    local n = 0
    for yy = 1, grid.rows or 0 do
        for xx = 1, grid.cols or 0 do
            local c = grid.cells[yy] and grid.cells[yy][xx]
            local enc = c and c.encounter
            if enc and not c.cleared and Dressing.eligible(enc) and enc.dressing == nil then
                Dressing.stamp(enc, { seed = ctx and ctx.seed, floor = ctx and ctx.floor,
                    biome = ctx and ctx.biome, x = xx, y = yy })
                n = n + 1
            end
        end
    end
    return n
end

-- How many of the three a dressing carries -- the cap's own measure.
function Dressing.count(d)
    if not d then return 0 end
    return (d.affixes and 1 or 0) + (d.objective and 1 or 0) + (d.condition and 1 or 0)
end

-- ---------------------------------------------------------------------------
-- What the screens say
-- ---------------------------------------------------------------------------

-- The rows the map's encounter card adds (ui/encounter_tooltip.lua), as tile_tooltip stat blocks.
function Dressing.rows(enc)
    local d = enc and enc.dressing
    if not d then return {} end
    local rows = {}
    if d.objective then
        rows[#rows + 1] = { kind = "stat", label = "Objective", value = Dressing.KIND_LABEL[d.objective] or d.objective }
    end
    if d.affixes and #d.affixes > 0 then
        local names = {}
        for i, id in ipairs(d.affixes) do names[i] = (Affix.defs[id] and Affix.defs[id].name) or id end
        rows[#rows + 1] = { kind = "stat", label = #d.affixes .. " affixed", value = table.concat(names, ", ") }
    end
    if d.condition then
        local def = Condition.defs[d.condition]
        rows[#rows + 1] = { kind = "stat", label = "Ground", value = (def and def.name) or d.condition,
            valueColor = def and def.color or nil }
    end
    return rows
end

-- The deploy screen's standing notices, as separate lines: the condition's first, then whatever else
-- the fight says (the Rooted Oath's, models/relic.lua). Kept apart so the deploy phase can fit each on
-- rows of its own (DeployPhase.noticeRows) -- joined into one string, the Oath's warning was the tail an
-- ellipsis cut off, on exactly the reach, hold and escape fights it is about. An empty list when there
-- is nothing to say.
function Dressing.noticeLines(combat, other)
    local lines = {}
    local line = Condition.line(combat and combat.condition)
    if line then lines[#lines + 1] = line end
    if other then lines[#lines + 1] = other end
    return lines
end

-- The same, as one string (for a reader with one line to give). Nil when there is nothing to say.
function Dressing.notice(combat, other)
    local lines = Dressing.noticeLines(combat, other)
    return #lines > 0 and table.concat(lines, "  ") or nil
end

-- The HUD's objective row carries the condition's name after the work: "Objective: Defeat every enemy
-- -- Fog". A suffix, so the row's own wrapping measures it.
function Dressing.hudSuffix(combat)
    local def = Condition.of(combat)
    return def and (" -- " .. def.name) or ""
end

return Dressing
