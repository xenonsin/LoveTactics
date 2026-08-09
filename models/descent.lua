-- The Descent: a run is a stack of FLOORS with a landing between each, and the landing asks the only
-- question the overworld never used to -- go deeper, or take what you have and leave.
--
-- This module owns the run's SHAPE and nothing else. No love.graphics, no UI, no state switching, so it
-- loads and tests under the headless runner exactly as models/draft_run.lua does (which is the working
-- precedent for a persistent multi-stage run and is worth reading beside this).
--
-- WHY THIS IS SO SMALL. states/game.lua never consults Quest.defs -- it reads `quest.id`, `quest.map`,
-- `quest.sponsor`, `quest.opening/intro/outro/followUp`, `quest.floorLevel` and `quest.endsCampaign` and
-- nothing else. So a SYNTHESIZED floor descriptor is a legal quest, and the entire overworld / battle /
-- spoils / relic / muster stack runs on one unchanged. Descent.floorQuest below is that descriptor; the
-- game state's whole share of this feature is a branch and a call.
--
--   local run = Descent.new(player)
--   State.switch(states.game, Descent.floorQuest(run), prestige, player)
--   -- ... floor clears -> the landing -> Descent.advance(run) -> floorQuest again, or Descent.extract
--
-- WHAT A RUN CARRIES, and the one rule about it: `run` is PLAIN DATA -- ids, numbers, booleans and flat
-- tables. It is serialized whole by models/save.lua, and Save.encode raises on a function value, so a
-- closure that finds its way in here does not fail gracefully, it takes the whole save write down with
-- it. The quest blueprints build `objective.composition` as a closure, which is exactly the sort of
-- thing that could drift in later -- so floorQuest BUILDS the descriptor fresh on every call and the run
-- never stores one. tests/descent_spec.lua pins the round trip.
--
-- STAGE 1 SCOPE. Floors are procedural and every floor ends in a `meet` stair. The sins, the shuffle and
-- the stair guardians land in later stages; the seams they need are marked below.

local Descent = {}

-- The seven biomes, which are also (from stage 2) the seven circles. Ordered so the id list is stable
-- for the hash below -- a run must lay out the same floors from the same seed on any machine, and
-- `pairs` over a registry is unspecified.
Descent.BIOMES = { "forest", "swamp", "desert", "volcanic", "tundra", "castle", "underworld" }

-- How many STOPS a floor's board hosts -- not how many fights. models/overworld.lua's combatShare caps
-- combat at a share of this and re-seats the rest as texture (a rest, a cache, a merchant), so the
-- number here buys density rather than battles.
--
-- Deliberately low for now. The plan's target is a Dream Quest board of 10-12 stops, and that only
-- becomes playable once an ordinary fight is a two-minute skirmish rather than a six-minute set-piece
-- (the skirmish tier). Raising this before that lands would produce a forty-minute floor. One constant,
-- so that stage is a one-line change here.
--
-- WHAT ELSE THAT ONE LINE MOVES, measured on a generated floor at both densities: caches are derived
-- from the stop count at about one per two stops (Overworld.generate), so twelve stops is six caches
-- rather than two, and a cache is the largest single source of forging material on the board. Craft
-- and house stock come out around three times what a rung costs instead of about one -- the rule the
-- stage-2 payout rebase was measured against (models/spoils.lua). So the density bump has to pin
-- `cacheCount` on the floor descriptor below rather than let it derive, or the material economy
-- inflates silently behind a change that looks like it is only about pacing.
Descent.FLOOR_STOPS = { min = 3, max = 4 }

-- The enemy-level floor for a given depth: "a fight on this floor is never easier than this". Same
-- meaning the authored `floorLevel` has everywhere else (models/growth.lua's combatantLevel), which is
-- why it can simply ride on the descriptor.
--
-- Two per floor, anchored so floor 7 reads 13 -- the value Quest.SLOT_FLOOR used to hand the deepest
-- quest of a line. An endless descent cannot have a hand-typed ladder, so this replaces that table.
Descent.LEVEL_PER_FLOOR = 2

-- Ids are `descent_f<N>`. Nothing in the engine ever looks a floor up in Quest.defs -- models/save.lua
-- branches on the presence of a stored descent BEFORE it tries Quest.get -- but the prefix keeps a floor
-- id recognisable in a save file and in a log line.
local ID_PREFIX = "descent_f"

-- ---------------------------------------------------------------------------
-- Determinism
-- ---------------------------------------------------------------------------

-- A floor's layout has to reproduce from (seed, floor) alone: the run is saved as a seed and a depth,
-- and a resume re-derives everything from them. So this is a plain integer hash rather than a stateful
-- RNG -- an RNG would have to store its position too, and would drift the moment anything else drew
-- from it. Pure, headless, and identical on every machine.
--
-- Bit ops are avoided on purpose: this is Lua 5.1 (LOVE's interpreter) and it has none. Multiply-and-mod
-- over values that stay well inside a double's exact-integer range does the same job.
local function hash(seed, floor, salt)
    local h = ((seed or 0) % 1000003) * 31 + (floor or 0) * 7919 + (salt or 0) * 104729
    h = (h * 1103515245 + 12345) % 2147483648
    return h
end

-- ---------------------------------------------------------------------------
-- Lifecycle
-- ---------------------------------------------------------------------------

-- Start a descent. `seed` is optional and exists so a spec can pin a run; live play rolls one.
--
-- `entry` is left nil here and filled by states/game.lua on the first floor, because the rollback point
-- is a Save.snapshot and this module deliberately knows nothing about the save format. What matters is
-- that it lives on the RUN rather than on the floor: the whole descent is one expedition, so the
-- snapshot is taken once at the top and every floor after it shares the same way back.
function Descent.new(player, seed)
    return {
        floor = 1,
        seed = seed or (os.time() % 1000000),
        -- Taken at the first floor and then carried by reference for the rest of the descent. See above.
        entry = nil,
        -- Quest ids banked but not yet paid out. Nothing writes this until authored floors land; it is
        -- declared here so the shape of a run does not change under models/save.lua later.
        pending = {},
        -- The deepest floor this run has actually cleared, which is what a new depth record is measured
        -- against at extraction. Distinct from `floor`, which is where the party is standing.
        cleared = 0,
    }
end

-- How deep the party is standing, 1-based. The only number the difficulty ladder reads.
function Descent.depth(run)
    return (run and run.floor) or 1
end

function Descent.floorLevel(run)
    return 1 + (Descent.depth(run) - 1) * Descent.LEVEL_PER_FLOOR
end

-- Which biome this floor wears. From stage 2 this becomes the SIN, drawn from a per-run shuffle of the
-- seven; for now it is a deterministic pick so consecutive floors visibly differ and a resume rebuilds
-- the same one.
function Descent.biomeAt(run, floor)
    local n = #Descent.BIOMES
    return Descent.BIOMES[(hash(run and run.seed, floor, 1) % n) + 1]
end

function Descent.floorId(floor)
    return ID_PREFIX .. tostring(floor or 1)
end

function Descent.isFloorId(id)
    return type(id) == "string" and id:sub(1, #ID_PREFIX) == ID_PREFIX
end

-- THE SYNTHESIZED QUEST. Every field here is one states/game.lua actually reads; nothing else is
-- invented, and no field is a function.
--
-- The objective is a `meet` stair: states/game.lua's meet branch (the one the arena debut's walk-out
-- already uses) marks the tile cleared and ends the leg without a fight, which is precisely what a
-- stairwell wants. `ascent = true` puts it on the farthest dead end on the board
-- (Overworld:placeObjectiveAndGates), so the stair is the end of the road rather than a tile you might
-- stumble over on the way to somewhere else.
--
-- From stage 3 this objective becomes a guardian fight instead, and on a sin floor whose house standing
-- has topped out, that house's general. The branch goes here.
function Descent.floorQuest(run, player)
    local floor = Descent.depth(run)
    return {
        id = Descent.floorId(floor),
        name = "The Descent — Floor " .. floor,
        description = "Down.",
        -- No sponsor yet, so no house material is tagged on this run's caches and salvage
        -- (states/game.lua resolves game.houseMaterial from this). Stage 2 sets it from the floor's sin.
        sponsor = nil,
        floorLevel = Descent.floorLevel(run),
        -- The field states/game.lua keys the whole feature off. Carried by reference: the state reads it
        -- to know it is in a descent and to park it on player.activeRun.
        descent = run,
        map = {
            biome = Descent.biomeAt(run, floor),
            ascent = true,
            encounters = { min = Descent.FLOOR_STOPS.min, max = Descent.FLOOR_STOPS.max },
            -- cacheCount left nil so Overworld.generate derives it from the stop count, and keyCount 0
            -- because a floor is not a lock puzzle -- the stair is always reachable.
            keyCount = 0,
            objective = {
                name = "The Stair Down",
                meet = true,
            },
        },
    }
end

-- Step to the next floor. Records that the floor just left was cleared, which is what the depth record
-- is read from at extraction -- `floor` alone would over-report, since it is where the party is
-- standing rather than what they beat.
function Descent.advance(run)
    if not run then return end
    run.cleared = math.max(run.cleared or 0, run.floor or 1)
    run.floor = (run.floor or 1) + 1
    return run
end

-- The party has cleared a floor and is standing on its landing. Called before the extract-or-descend
-- prompt so both branches agree on what has been beaten.
function Descent.clearFloor(run)
    if not run then return end
    run.cleared = math.max(run.cleared or 0, run.floor or 1)
    return run.cleared
end

-- WALKING OUT WITH IT. Banks what the descent is owed to the player and returns a small summary the
-- caller can put on screen.
--
-- Stage 1 banks the depth record only. Standing per sin, the authored quests queued in `run.pending`
-- and the heroes bound this descent all drain through here in later stages -- one seam, so there is
-- never a second place that has to remember what extraction means.
--
-- The run's FINDS are not touched here and never will be: they have been live in the stash since the
-- moment they were picked up. What extraction does is drop the rollback point, which is the caller's
-- job (clearRun) because the snapshot lives on player.activeRun. See states/game.lua's rollbackRun for
-- the other half of that rule.
function Descent.extract(player, run)
    if not (player and run) then return nil end
    local reached = run.cleared or 0
    local best = player.deepest or 0
    local record = reached > best
    if record then player.deepest = reached end
    return { floors = reached, deepest = player.deepest or 0, record = record }
end

-- ---------------------------------------------------------------------------
-- Persistence
-- ---------------------------------------------------------------------------

-- Plain data only, and deliberately WITHOUT `entry`.
--
-- The rollback point is a full Save.snapshot -- the whole company, its grids and the stash -- and
-- models/save.lua's snapshotRun already writes it once at the run level. Serializing it here as well
-- would put a second copy of the entire player in every save, growing the file by a company per write.
-- So the descent holds `entry` in MEMORY (which is the point: it is what carries the rollback point from
-- one floor to the next, since each floor is a fresh game.enter that would otherwise re-snapshot and
-- quietly bank the last floor's finds) and Save.restoreRun re-attaches it on the way back in.
function Descent.snapshot(run)
    if type(run) ~= "table" then return nil end
    local pending = {}
    for i, id in ipairs(run.pending or {}) do pending[i] = id end
    return {
        floor = run.floor or 1,
        seed = run.seed or 0,
        cleared = run.cleared or 0,
        pending = pending,
    }
end

function Descent.restore(snap)
    if type(snap) ~= "table" then return nil end
    local pending = {}
    for i, id in ipairs(snap.pending or {}) do pending[i] = id end
    return {
        floor = snap.floor or 1,
        seed = snap.seed or 0,
        cleared = snap.cleared or 0,
        pending = pending,
        entry = nil, -- re-attached by Save.restoreRun from the run-level copy; see above
    }
end

return Descent
