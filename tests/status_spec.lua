-- Tests for the status-effect system (models/status.lua) and its combat hooks: stun shoving a
-- unit down the initiative order, root gating movement + charging the full move cost at end of
-- turn, tick-based expiry driven by the rebase amount, and duration refresh. Pure logic, headless.

local Character = require("models.character")
local Combat = require("models.combat")
local Status = require("models.status")

-- A flat, all-walkable arena (mirrors tests/combat_spec.lua's fixture).
local function arena(cols, rows, objective)
    local tiles = {}
    for y = 1, rows do
        tiles[y] = {}
        for x = 1, cols do
            tiles[y][x] = { type = "ground", moveCost = 1, walkable = true }
        end
    end
    return { cols = cols, rows = rows, tiles = tiles, objective = objective or { type = "killAll" } }
end

local function unit(charOrId, x, y)
    local char = type(charOrId) == "string" and Character.instantiate(charOrId) or charOrId
    return { char = char, x = x, y = y }
end

local function openTurn(c, u)
    c.turn = { unit = u, moved = false, moveCost = 0 }
end

return {
    {
        name = "stun adds ticks to the target's initiative, shoving it down the turn order",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("knight", 1, 1) }, { unit("bandit", 1, 2) })
            local knight, bandit = c.units[1], c.units[2]
            knight.initiative, bandit.initiative = 0.5, 0 -- bandit would act first
            assert(Combat.turnOrder(c)[1] == bandit, "bandit (0) acts first before the stun")

            Status.apply(c, bandit, "stun", { magnitude = 5 })
            assert(bandit.initiative == 5, "stun added 5 to the bandit's initiative, got " .. bandit.initiative)
            assert(Status.has(bandit, "stun"), "the stun status is recorded on the unit")
            assert(Combat.turnOrder(c)[1] == knight, "knight (0.5) now acts before the stunned bandit (5)")
        end,
    },
    {
        name = "root blocks movement and charges the full move cost at end of turn",
        fn = function()
            -- Knight (chainmail drops movement to 2, iron_sword speed 3) rooted, bandit parked far so
            -- the cost shows as elapsed clock. It cannot move, but can still attack -- and pays the
            -- full move cost.
            local c = Combat.new(arena(8, 8), { unit("knight", 3, 3) }, { unit("bandit", 3, 4) })
            local knight, bandit = c.units[1], c.units[2]
            knight.initiative, bandit.initiative = 0, 100
            Status.apply(c, knight, "root")
            openTurn(c, knight)

            assert(Combat.moveUnit(c, knight, 3, 2) == false, "a rooted unit cannot move")

            local clock0 = c.clock
            assert(Combat.useItem(c, knight, knight.char.inventory[1], 3, 4), "it can still strike adjacent")
            -- endTurn folds max(actual move 0, forced movement 2) + ability speed 3 = 5.
            assert(c.clock == clock0 + 5, "rooted turn costs full move (2) + ability speed (3), got "
                .. (c.clock - clock0))
        end,
    },
    {
        name = "Status.tick counts durations down by the elapsed ticks and expires at 0 (onExpire fires)",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("knight", 1, 1) }, {})
            local knight = c.units[1]

            -- A temporary status def with an onExpire hook (removed afterward so it can't leak).
            Status.defs.test_decay = { name = "Decay", duration = 5,
                onExpire = function(ctx) ctx.unit.char._expired = true end }

            Status.apply(c, knight, "test_decay")
            assert(Status.get(knight, "test_decay").remaining == 5, "starts at full duration")

            Status.tick(c, 3)
            assert(Status.get(knight, "test_decay").remaining == 2, "3 ticks elapsed -> 2 remaining")
            assert(not knight.char._expired, "not yet expired")

            Status.tick(c, 2)
            assert(not Status.has(knight, "test_decay"), "hitting 0 removes the status")
            assert(knight.char._expired, "onExpire fired on expiry")

            Status.defs.test_decay = nil -- don't leak the fixture to other specs
        end,
    },
    {
        name = "re-applying a status refreshes its remaining duration to the longer value",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("knight", 1, 1) }, {})
            local knight = c.units[1]
            Status.apply(c, knight, "root") -- duration 6
            Status.tick(c, 4)
            assert(Status.get(knight, "root").remaining == 2, "counted down to 2")

            Status.apply(c, knight, "root") -- refresh
            assert(Status.get(knight, "root").remaining == 6, "re-apply refreshes to the full 6")
            -- One instance per id: still a single root, not two.
            local count = 0
            for _, s in ipairs(knight.statuses) do if s.id == "root" then count = count + 1 end end
            assert(count == 1, "only one root instance is kept")
        end,
    },
    {
        name = "status durations tick down through the combat clock (rebase) as turns pass",
        fn = function()
            -- The bandit is rooted; the knight acts, advancing the clock by its turn cost, which
            -- should count the bandit's root down by the same amount via Combat.rebase -> Status.tick.
            local c = Combat.new(arena(8, 8), { unit("knight", 3, 3) }, { unit("bandit", 3, 4) })
            local knight, bandit = c.units[1], c.units[2]
            knight.initiative, bandit.initiative = 0, 100
            Status.apply(c, bandit, "root") -- duration 6
            assert(Status.get(bandit, "root").remaining == 6, "root starts at 6")

            Combat.startTurn(c)
            local clock0 = c.clock
            assert(Combat.useItem(c, knight, knight.char.inventory[1], 3, 4), "knight strikes (speed 3)")
            local elapsed = c.clock - clock0
            assert(elapsed == 3, "the knight's turn advanced the clock by 3")
            assert(Status.get(bandit, "root").remaining == 6 - elapsed,
                "the bandit's root counted down by the elapsed ticks")
        end,
    },
    {
        name = "Burn deals fire damage at each turn start and wears off after its duration",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("knight", 1, 1) }, { unit("bandit", 1, 2) })
            local bandit = c.units[2]
            bandit.char.stats.defense = 0 -- isolate the tick from defense mitigation
            local hp0 = bandit.char.stats.health.current
            Status.apply(c, bandit, "burn") -- duration 3, magnitude 4
            assert(Status.get(bandit, "burn").remaining == 3, "burn starts at duration 3")

            Status.onTurnStart(c, bandit)
            assert(bandit.char.stats.health.current == hp0 - 4, "a burn tick deals 4 fire damage")

            Status.tick(c, 3)
            assert(not Status.has(bandit, "burn"), "burn wears off after its duration")
        end,
    },
}
