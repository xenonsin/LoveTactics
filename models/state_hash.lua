-- A fingerprint of a battle's state, for telling two machines they still agree.
--
-- Lockstep's whole bet is that both peers, given the same seed and the same commands, compute the
-- same fight. This is how the bet is checked: after every command each peer fingerprints its own
-- board and they compare. Matching means nothing has drifted; differing means the two are playing
-- different games and there is no honest way to continue (see the desync policy in the plan).
--
-- TWO OUTPUTS, deliberately:
--   StateHash.of(combat)     -- the full encoded state, as sorted-key Lua source
--   StateHash.digest(source) -- a short string to actually put on the wire
--
-- The long form is the reason this reuses save.lua's encoder rather than hashing bytes directly.
-- When a desync happens, the only question worth answering fast is WHICH FIELD diverged, and two
-- sorted-key dumps answer it with a plain text diff. A fast binary hash would tell you that
-- something broke and nothing about what. Bandwidth is not the constraint here -- turns are seconds
-- apart -- so debuggability wins.
--
-- WHAT IS INCLUDED is everything the rules read: positions, health, the timeline, statuses, and the
-- things on the board that act. What is left out is either static (the arena, rebuilt from the seed
-- on both sides), presentation (the fx queue, the log), or genuinely local:
--
--   * `classUse` is the big one. Each machine tallies growth only for the units it drives -- that is
--     correct, and it means the tallies MUST differ between peers. Hashing it would report a desync
--     on the first swing of every duel.
--   * Character names and sprites: cosmetic, and a remote roster carries the author's names.
--
-- Pure data in, string out. No love.*, so it runs headless in the suite.

local Save = require("models.save")

local StateHash = {}

-- Statuses as a sorted list of { id, remaining }. Sorted because the model keeps them in whatever
-- order they landed, and two peers can reach the same set by different routes -- a differently
-- ORDERED identical set is not a disagreement about the fight.
local function statusesOf(unit)
    local out = {}
    for _, st in ipairs(unit.statuses or {}) do
        out[#out + 1] = { id = st.id, remaining = st.remaining }
    end
    table.sort(out, function(a, b)
        if a.id ~= b.id then return tostring(a.id) < tostring(b.id) end
        return (a.remaining or 0) < (b.remaining or 0)
    end)
    return out
end

local function poolOf(stats, key)
    local v = stats and stats[key]
    if type(v) == "table" then return v.current end
    return v
end

local function unitsOf(combat)
    local out = {}
    for i, u in ipairs(combat.units or {}) do
        local stats = u.char and u.char.stats or {}
        out[i] = {
            id = u.char and u.char.id,
            side = u.side,
            -- `control` is deliberately NOT here. It says who drives this unit ON THIS MACHINE, and
            -- in a duel it is necessarily opposite between the two peers: each sees its own units as
            -- "player" and the other's as "remote". Hashing it reports a desync on turn one of every
            -- duel -- which is exactly what it did, the first time two windows ran the real battle
            -- against each other. `side` is the shared fact and is hashed; `control` is local.
            x = u.x, y = u.y,
            alive = u.alive and true or false,
            summoned = u.summoned and true or false,
            initiative = u.initiative,
            health = poolOf(stats, "health"),
            mana = poolOf(stats, "mana"),
            stamina = poolOf(stats, "stamina"),
            statuses = statusesOf(u),
        }
    end
    return out
end

-- Board furniture that acts: traps waiting to spring, hazards burning, walls in the way. Positions
-- and identity only -- enough that a peer which sprang a trap the other did not is caught.
local function boardOf(combat)
    local traps = {}
    for i, t in ipairs(combat.traps or {}) do
        traps[i] = { id = t.id, x = t.x, y = t.y, side = t.side,
                     health = t.health, alive = t.alive and true or false }
    end
    local hazards = {}
    for i, h in ipairs(combat.hazards or {}) do
        hazards[i] = { id = h.id, x = h.x, y = h.y, side = h.side, remaining = h.remaining }
    end
    local walls = {}
    for i, w in ipairs(combat.walls or {}) do
        walls[i] = { id = w.id, x = w.x, y = w.y, side = w.side,
                     health = w.health, remaining = w.remaining }
    end
    return traps, hazards, walls
end

-- The full state, as sorted-key Lua source. Stable across runs and machines: every table here is
-- built in a fixed order, and Save.encode sorts keys.
function StateHash.of(combat)
    local traps, hazards, walls = boardOf(combat)
    local turn = combat.turn
    local projection = {
        clock = combat.clock,
        turnCount = combat.turnCount,
        units = unitsOf(combat),
        traps = traps,
        hazards = hazards,
        walls = walls,
        -- Whose turn it is, and what they have already spent of it. A peer that thinks the move is
        -- still available has diverged even if every body is still standing in the same place.
        turn = turn and {
            unit = turn.unit and turn.unit.index,
            moved = turn.moved and true or false,
            moveCost = turn.moveCost,
        } or nil,
    }
    return Save.encode(projection, 0)
end

-- A short, comparable digest of `source` -- what actually travels.
--
-- Two independent polynomial lanes, each reduced mod a prime under 2^24, so every intermediate
-- stays well inside a double's exact range and the result is identical on every platform we ship.
-- Deliberately no bitwise operators: LOVE runs LuaJIT (Lua 5.1 semantics), where `~` is not xor and
-- the bit library is a separate dependency -- arithmetic is both portable and sufficient here.
--
-- Not cryptographic and does not need to be. It guards against drift, not against an opponent
-- forging agreement, which lockstep cannot defend against anyway.
local MOD = 16777213 -- largest prime below 2^24

function StateHash.digest(source)
    local a, b = 5381, 52711
    for i = 1, #source do
        local c = source:byte(i)
        a = (a * 33 + c) % MOD
        b = (b * 31 + c * (i % 251)) % MOD
    end
    return string.format("%06x%06x", a, b)
end

-- Convenience: fingerprint `combat` straight to the short form.
function StateHash.digestOf(combat)
    return StateHash.digest(StateHash.of(combat))
end

return StateHash
