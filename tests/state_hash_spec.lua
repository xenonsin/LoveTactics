-- Tests for models/state_hash.lua: the fingerprint two peers compare to know they still agree.
--
-- The instrument has to be sharp in both directions. A hash that misses a divergence lets a duel
-- run on as two different games; a hash that reports one over something local (a growth tally each
-- machine keeps for its own units) makes lockstep unusable by crying wolf on turn one. Both
-- failures are checked here.
--
-- Pure logic, runs headless.

local StateHash = require("models.state_hash")
local Combat = require("models.combat")
local Character = require("models.character")
local Item = require("models.item")

local function arena(cols, rows, seed)
    local tiles = {}
    for y = 1, rows do
        tiles[y] = {}
        for x = 1, cols do
            tiles[y][x] = { type = "ground", moveCost = 1, walkable = true, sightCost = 0 }
        end
    end
    return { cols = cols, rows = rows, tiles = tiles, objective = { type = "killAll" }, seed = seed }
end

local function unit(id, x, y)
    local char = Character.instantiate(id)
    char.traits = {}
    for i = 1, Character.MAX_INVENTORY do
        if char.inventory[i] and char.inventory[i].bound then char.inventory[i] = nil end
    end
    return { char = char, x = x, y = y }
end

-- Two independently built battles that should be indistinguishable.
local function pair()
    local function build()
        return Combat.new(arena(8, 8, 77),
            { unit("character_knight", 4, 8) }, { unit("character_bandit", 4, 1) })
    end
    return build(), build()
end

return {
    {
        name = "two battles built the same way fingerprint the same",
        fn = function()
            local a, b = pair()
            assert(StateHash.of(a) == StateHash.of(b), "identical boards should encode identically")
            assert(StateHash.digestOf(a) == StateHash.digestOf(b), "and digest identically")
        end,
    },
    {
        name = "the fingerprint notices what the rules actually read",
        fn = function()
            local moved = { "a body moving", function(c) c.units[1].x = c.units[1].x - 1 end }
            local hurt = { "a wound", function(c) c.units[2].char.stats.health.current = 3 end }
            local dead = { "a death", function(c) c.units[2].alive = false end }
            local clock = { "the clock", function(c) c.clock = c.clock + 5 end }
            local init = { "the timeline", function(c) c.units[1].initiative = 99 end }
            local moves = { "a spent move", function(c)
                c.turn = { unit = c.units[1], moved = true, moveCost = 3 }
            end }

            for _, case in ipairs({ moved, hurt, dead, clock, init, moves }) do
                local a, b = pair()
                case[2](b)
                assert(StateHash.of(a) ~= StateHash.of(b), case[1] .. " should change the state")
                assert(StateHash.digestOf(a) ~= StateHash.digestOf(b),
                    case[1] .. " should change the digest too")
            end
        end,
    },
    {
        -- The failure that would make lockstep unusable rather than unsafe. Each peer records class
        -- use only for the units it drives, which is correct and means the tallies MUST differ. If
        -- that reached the hash, every duel would "desync" on its first swing.
        name = "a growth tally is local bookkeeping and must not read as disagreement",
        fn = function()
            local a, b = pair()
            b.units[1].char.classUse = { fighter = 7 }
            b.units[2].char.classUse = { mage = 3 }
            assert(StateHash.of(a) == StateHash.of(b),
                "class tallies are per-machine and belong nowhere near the fingerprint")
        end,
    },
    {
        -- Same reasoning: the fx queue is a list of things still to be DRAWN. One peer may have
        -- drained it a frame earlier than the other without either being wrong about the fight.
        name = "pending animation cues are not part of the state",
        fn = function()
            local a, b = pair()
            Combat.pushFx(b, { type = "damage", unit = b.units[2], amount = 4 })
            b.log[#b.log + 1] = { kind = "action", text = "something happened" }
            assert(StateHash.of(a) == StateHash.of(b),
                "cues and log lines are presentation, not state")
        end,
    },
    {
        -- Statuses land in whatever order they were applied. Two peers can reach an identical set by
        -- different routes, and a differently ordered identical set is not a disagreement.
        name = "the same statuses in a different order are the same state",
        fn = function()
            local a, b = pair()
            a.units[1].statuses = {
                { id = "status_burn", remaining = 6 },
                { id = "status_slow", remaining = 3 },
            }
            b.units[1].statuses = {
                { id = "status_slow", remaining = 3 },
                { id = "status_burn", remaining = 6 },
            }
            assert(StateHash.of(a) == StateHash.of(b), "status order is not state")

            b.units[1].statuses[1].remaining = 4
            assert(StateHash.of(a) ~= StateHash.of(b), "but a status's remaining time is")
        end,
    },
    {
        name = "the long form is diffable, which is the point of keeping it",
        fn = function()
            local a, b = pair()
            b.units[1].x = b.units[1].x - 1
            local sa, sb = StateHash.of(a), StateHash.of(b)
            assert(sa ~= sb, "the two should differ")
            assert(sa:find("%[\"x\"%]"), "the dump should name its fields, for diffing")
            -- Sorted keys mean the two dumps line up rather than shuffling.
            assert(#sa > 100 and #sb > 100, "and be substantial enough to locate a field in")
        end,
    },
    {
        name = "the digest is short, stable, and portable arithmetic",
        fn = function()
            local a = pair()
            local d = StateHash.digestOf(a)
            assert(#d == 12, "a digest should be 12 hex characters, got " .. #d .. " (" .. d .. ")")
            assert(d:match("^%x+$"), "and hex throughout: " .. d)
            assert(StateHash.digest("") == StateHash.digest(""), "and deterministic")
            assert(StateHash.digest("a") ~= StateHash.digest("b"), "and sensitive to its input")
        end,
    },
    {
        -- Duplicate blueprints on one team are ordinary now that a build can field them, and the
        -- fingerprint keys units by position for exactly that reason.
        name = "two of the same blueprint are two units, not one",
        fn = function()
            local function twins()
                return Combat.new(arena(8, 8, 5),
                    { unit("character_knight", 3, 8), unit("character_knight", 5, 8) }, {})
            end
            local a, b = twins(), twins()
            assert(StateHash.of(a) == StateHash.of(b), "twin teams should match")

            b.units[2].x = 6
            assert(StateHash.of(a) ~= StateHash.of(b),
                "moving the SECOND twin must be visible; keying by char id would hide it")
        end,
    },
}
