-- Tests for the combat log's SUBJECTS: the unit references Combat.logEvent hangs on each entry
-- (entry.units). They are what lets the log panel point back at the battlefield -- hovering a line
-- rings the units it names on the board and on the initiative strip (ui/combat_log.lua's
-- :hoveredUnits, read by states/battle.lua). A line that names nobody can't be pointed at, so the
-- lines that matter most -- who moved, who was hit, who fell -- have to carry them.
--
-- Pure model data, runs headless.

local Character = require("models.character")
local Item = require("models.item")
local Combat = require("models.combat")

-- A flat, all-walkable arena (mirrors tests/breakdown_spec.lua's fixture).
local function arena(cols, rows)
    local tiles = {}
    for y = 1, rows do
        tiles[y] = {}
        for x = 1, cols do tiles[y][x] = { type = "ground", moveCost = 1, walkable = true } end
    end
    return { cols = cols, rows = rows, tiles = tiles, objective = { type = "killAll" } }
end

local function unit(id, x, y) return { char = Character.instantiate(id), x = x, y = y } end

-- The first log entry of `kind`, or nil.
local function firstOf(combat, kind)
    for _, e in ipairs(combat.log) do if e.kind == kind then return e end end
    return nil
end

-- Does `entry` name `u` among its subjects?
local function names(entry, u)
    for _, s in ipairs((entry and entry.units) or {}) do if s == u then return true end end
    return false
end

return {
    {
        name = "logEvent takes a bare unit or a list, and keeps only real units",
        fn = function()
            local c = Combat.new(arena(4, 4), { unit("character_warlord", 1, 1) },
                { unit("character_bandit", 1, 2) })
            local a, b = c.units[1], c.units[2]

            local bare = Combat.logEvent(c, "system", "one", a)
            assert(bare.units and #bare.units == 1 and bare.units[1] == a, "a bare unit becomes a one-entry list")

            local pair = Combat.logEvent(c, "system", "two", { a, b })
            assert(pair.units and #pair.units == 2, "a list is kept whole")
            assert(pair.units[1] == a and pair.units[2] == b, "and in the order the model named them")

            -- A maybe-attacker is passed straight through by callers, so a nil tail must not explode.
            local partial = Combat.logEvent(c, "system", "three", { a, nil })
            assert(partial.units and #partial.units == 1, "a nil subject is dropped, not stored")

            -- Non-units (a stray string, a trap table) are not something the board can ring.
            local junk = Combat.logEvent(c, "system", "four", { "a trap", { x = 1, y = 1 } })
            assert(junk.units == nil, "nothing unit-shaped survives, and no empty list is left behind")

            local none = Combat.logEvent(c, "system", "five")
            assert(none.units == nil, "a line about nobody carries no subjects")
        end,
    },
    {
        name = "a damage line names both the struck and whoever struck them",
        fn = function()
            local c = Combat.new(arena(6, 6), { unit("character_warlord", 1, 1) },
                { unit("character_bandit", 1, 2) })
            local attacker, target = c.units[1], c.units[2]
            Combat.dealDamage(c, attacker, target, Item.instantiate("weapon_iron_sword"), {})

            local hit = firstOf(c, "damage")
            assert(hit, "the blow logged a damage line")
            assert(hit.units and hit.units[1] == target, "the struck leads -- the line is about them")
            assert(names(hit, attacker), "and the striker is named beside them, so the pair reads as one event")
        end,
    },
    {
        name = "a move line names the unit that walked",
        fn = function()
            local c = Combat.new(arena(6, 6), { unit("character_warlord", 1, 1) },
                { unit("character_bandit", 5, 5) })
            Combat.startTurn(c)
            local mover = Combat.currentUnit(c)
            local plan = Combat.planMove(c, mover, mover.x + 1, mover.y)
            assert(plan, "a one-tile walk is plannable")
            Combat.beginMove(c, plan)

            local moved = firstOf(c, "move")
            assert(moved and names(moved, mover), "the mover is the move line's subject")
        end,
    },
    {
        name = "a death line names the fallen, so a corpse can still be pointed at",
        fn = function()
            local c = Combat.new(arena(6, 6), { unit("character_warlord", 1, 1) },
                { unit("character_bandit", 1, 2) })
            local target = c.units[2]
            Combat.dealFlatDamage(c, target, 9999, { "physical" }, "the void")
            assert(not target.alive, "the bandit is down")

            local death = firstOf(c, "death")
            assert(death and names(death, target), "the fallen unit is the death line's subject")
        end,
    },
    {
        name = "a status line names its bearer",
        fn = function()
            local c = Combat.new(arena(6, 6), { unit("character_warlord", 1, 1) },
                { unit("character_bandit", 1, 2) })
            local Status = require("models.status")
            local bearer = c.units[2]
            Status.apply(c, bearer, "status_acid")

            local st = firstOf(c, "status")
            assert(st and names(st, bearer), "the afflicted unit is the status line's subject")
        end,
    },
}
