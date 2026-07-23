-- Tests for the status-effect system (models/status.lua) and its combat hooks: stun shoving a
-- unit down the initiative order, root gating movement + charging the full move cost at end of
-- turn, tick-based expiry driven by the rebase amount, and duration refresh. Pure logic, headless.

local Character = require("models.character")
local Item = require("models.item")
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

-- The two cases below measure the CLOCK against a known ability speed, so they need a unit whose
-- weapon speed they can state. `character_knight` used to be that by accident -- Rowan carried a
-- sword (speed 3) -- until the prologue gave her an iron mace (speed 4), which silently changed the
-- arithmetic of tests that were never about her. The sword goes in explicitly now.
local function swordsman(x, y)
    local char = Character.instantiate("character_knight")
    char.inventory[1] = Item.instantiate("weapon_iron_sword")
    return { char = char, x = x, y = y }
end

local function openTurn(c, u)
    c.turn = { unit = u, moved = false, moveCost = 0 }
end

return {
    {
        name = "stun adds ticks to the target's initiative, shoving it down the turn order",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_knight", 1, 1) }, { unit("character_bandit", 1, 2) })
            local knight, bandit = c.units[1], c.units[2]
            knight.initiative, bandit.initiative = 0.5, 0 -- bandit would act first
            assert(Combat.turnOrder(c)[1] == bandit, "bandit (0) acts first before the stun")

            Status.apply(c, bandit, "status_stun", { magnitude = 5 })
            assert(bandit.initiative == 5, "stun added 5 to the bandit's initiative, got " .. bandit.initiative)
            assert(Status.has(bandit, "status_stun"), "the stun status is recorded on the unit")
            assert(Combat.turnOrder(c)[1] == knight, "knight (0.5) now acts before the stunned bandit (5)")
        end,
    },
    {
        name = "Status.initiativeShove reports the delay a hard-control status lands (0 for the rest)",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_knight", 1, 1) }, { unit("character_bandit", 1, 2) })
            local bandit = c.units[2]
            -- Stun/Freeze: a fixed shove, the opts value winning over the def default.
            assert(Status.initiativeShove(bandit, "status_stun") == 5, "stun's default shove is its magnitude")
            assert(Status.initiativeShove(bandit, "status_stun", { magnitude = 10 }) == 10, "opts tunes the shove")
            assert(Status.initiativeShove(bandit, "status_freeze") == 5, "freeze shoves by its magnitude too")
            -- A status that doesn't touch initiative shoves nothing at all.
            assert(Status.initiativeShove(bandit, "status_bleed") == 0, "a bleed is no delay")
            -- Sleep reads its shove off the (resisted) duration -- the same number onApply uses.
            local sleepShove = Status.initiativeShove(bandit, "status_sleep")
            assert(sleepShove > 0, "sleep shoves down the order")
            assert(sleepShove == Status.resistedDuration(bandit, "status_sleep", 14),
                "sleep's shove is its resisted remaining, got " .. sleepShove)
        end,
    },
    {
        name = "previewAbility projects a stunned target's delayed turn onto the timeline",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_mage", 1, 1) }, { unit("character_bandit", 1, 2) })
            local mage, bandit = c.units[1], c.units[2]
            mage.char.inventory[1] = Item.instantiate("ability_jolt")
            bandit.initiative = 2

            local preview = Combat.previewAbility(c, mage, mage.char.inventory[1], bandit.x, bandit.y)
            local e = preview.entries[bandit]
            assert(e, "the bandit is an affected target")
            assert(not e.lethal, "a Jolt doesn't fell a healthy bandit (so the ghost is worth showing)")
            -- Jolt's base stun is 10 (its per-level `stun` curve at level 0), carried on the hit.
            assert(e.initiativeAfter == bandit.initiative + 10,
                "the ghost lands at initiative + stun, got " .. tostring(e.initiativeAfter))
            assert(e.initiativeCause == "Stun", "the ghost is labelled by its cause")
            -- Pure: previewing the shove never touched the live initiative.
            assert(bandit.initiative == 2, "the dry run left the bandit's real initiative alone")
        end,
    },
    {
        name = "root blocks movement and charges the full move cost at end of turn",
        fn = function()
            -- Knight (chainmail drops movement to 2, iron_sword speed 3) rooted, bandit parked far so
            -- the cost shows as elapsed clock. It cannot move, but can still attack -- and pays the
            -- full move cost.
            local c = Combat.new(arena(8, 8), { swordsman(3, 3) }, { unit("character_bandit", 3, 4) })
            local knight, bandit = c.units[1], c.units[2]
            knight.initiative, bandit.initiative = 0, 100
            Status.apply(c, knight, "status_root")
            openTurn(c, knight)

            assert(Combat.moveUnit(c, knight, 3, 2) == false, "a rooted unit cannot move")

            local clock0 = c.clock
            assert(Combat.useItem(c, knight, knight.char.inventory[1], 3, 4), "it can still strike adjacent")
            -- endTurn folds max(actual move 0, forced movement 3) + ability speed 3 = 6. The knight's
            -- budget is base 4 less chainmail's square: Root bills the full walk it never took.
            assert(c.clock == clock0 + 6, "rooted turn costs full move (3) + ability speed (3), got "
                .. (c.clock - clock0))
        end,
    },
    {
        name = "Status.tick counts durations down by the elapsed ticks and expires at 0 (onExpire fires)",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_knight", 1, 1) }, {})
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
            local c = Combat.new(arena(8, 8), { unit("character_knight", 1, 1) }, {})
            local knight = c.units[1]
            Status.apply(c, knight, "status_root") -- duration 6
            Status.tick(c, 4)
            assert(Status.get(knight, "status_root").remaining == 2, "counted down to 2")

            Status.apply(c, knight, "status_root") -- refresh
            assert(Status.get(knight, "status_root").remaining == 6, "re-apply refreshes to the full 6")
            -- One instance per id: still a single root, not two.
            local count = 0
            for _, s in ipairs(knight.statuses) do if s.id == "status_root" then count = count + 1 end end
            assert(count == 1, "only one root instance is kept")
        end,
    },
    {
        name = "status durations tick down through the combat clock (rebase) as turns pass",
        fn = function()
            -- The bandit is rooted; the knight acts, advancing the clock by its turn cost, which
            -- should count the bandit's root down by the same amount via Combat.rebase -> Status.tick.
            local c = Combat.new(arena(8, 8), { swordsman(3, 3) }, { unit("character_bandit", 3, 4) })
            local knight, bandit = c.units[1], c.units[2]
            knight.initiative, bandit.initiative = 0, 100
            Status.apply(c, bandit, "status_root") -- duration 6
            assert(Status.get(bandit, "status_root").remaining == 6, "root starts at 6")

            Combat.startTurn(c)
            local clock0 = c.clock
            assert(Combat.useItem(c, knight, knight.char.inventory[1], 3, 4), "knight strikes (speed 3)")
            local elapsed = c.clock - clock0
            assert(elapsed == 3, "the knight's turn advanced the clock by 3")
            assert(Status.get(bandit, "status_root").remaining == 6 - elapsed,
                "the bandit's root counted down by the elapsed ticks")
        end,
    },
    {
        name = "Burn sears on the clock: a turn's worth of ticks costs its per-turn magnitude",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_knight", 1, 1) }, { unit("character_bandit", 1, 2) })
            local bandit = c.units[2]
            bandit.char.stats.defense = 0 -- isolate the burn from defense mitigation
            local hp0 = bandit.char.stats.health.current
            -- A generous duration, so a whole turn's worth of ticks falls INSIDE its life: what is on
            -- trial here is the per-turn -> per-tick conversion, not Burn's own tuning (its stock
            -- duration of 3 ticks is shorter than the ~5 a turn costs, so it would only live to earn a
            -- fraction -- see the case below).
            Status.apply(c, bandit, "status_burn", { duration = 20 }) -- magnitude 4 per turn
            Status.tick(c, Status.TICKS_PER_TURN)
            assert(bandit.char.stats.health.current == hp0 - 4,
                "a turn's worth of ticks deals exactly the per-turn magnitude, got "
                    .. (hp0 - bandit.char.stats.health.current))
        end,
    },
    {
        name = "a status ticks for the stretch it was alive, then wears off -- never for a rebase it did not see",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_knight", 1, 1) }, { unit("character_bandit", 1, 2) })
            local bandit = c.units[2]
            bandit.char.stats.defense = 0
            local hp0 = bandit.char.stats.health.current
            -- A deliberately SHORT burn -- shorter than the rebase below -- rather than the stock
            -- duration: what is on trial is the slicing, and pinning it to Burn's own tuning would make
            -- this spec fail every time someone retunes the fire.
            Status.apply(c, bandit, "status_burn", { duration = 3 }) -- magnitude 4 per turn
            assert(Status.get(bandit, "status_burn").remaining == 3, "the burn starts with 3 ticks to live")

            -- One rebase elapsing MORE ticks than the burn has left. It must be paid for the 3 ticks it
            -- actually lived (4/turn over 3 of 5 ticks = 2.4, and only whole points are spent), not for
            -- all 5 -- and it must not be deleted before it burns at all, which is what ageing ahead of
            -- the tick would do.
            Status.tick(c, Status.TICKS_PER_TURN)
            assert(bandit.char.stats.health.current == hp0 - 2,
                "it sears for the 3 ticks it lived and no further, got "
                    .. (hp0 - bandit.char.stats.health.current))
            assert(not Status.has(bandit, "status_burn"), "and those same ticks ran its duration out")
        end,
    },
    {
        name = "Burn's fractional ticks accrue rather than each rounding up to a full point",
        fn = function()
            -- The reason ctx.accrue banks a remainder: a rebase can elapse a fraction of a tick, and
            -- damage floors at 1, so paying each sliver immediately would sear far harder than the
            -- magnitude claims. Ten tenth-of-a-tick rebases must cost exactly what one whole tick does.
            local c = Combat.new(arena(8, 8), { unit("character_knight", 1, 1) }, { unit("character_bandit", 1, 2) })
            local bandit = c.units[2]
            bandit.char.stats.defense = 0
            local hp0 = bandit.char.stats.health.current
            Status.apply(c, bandit, "status_burn") -- 4 per turn = 0.8 per tick at TICKS_PER_TURN = 5

            for _ = 1, 10 do Status.tick(c, 0.1) end -- one tick's worth, in ten slivers
            local dealt = hp0 - bandit.char.stats.health.current
            assert(dealt == 0, "less than a whole point has accrued, so nothing is spent yet, got " .. dealt)

            for _ = 1, 10 do Status.tick(c, 0.1) end -- a second tick's worth: 1.6 accrued -> 1 spent
            dealt = hp0 - bandit.char.stats.health.current
            assert(dealt == 1, "the banked fraction pays out a whole point and no more, got " .. dealt)
        end,
    },
    {
        name = "Haste halves ability costs and pulls its target up the turn order",
        fn = function()
            local priest = Character.instantiate("character_priest")
            priest.inventory = {}
            Character.addItem(priest, Item.instantiate("ability_haste"))
            local knight = Character.instantiate("character_knight")
            knight.inventory = {}
            Character.addItem(knight, Item.instantiate("weapon_iron_sword"))

            local c = Combat.new(arena(8, 8), { unit(priest, 1, 1), unit(knight, 2, 1) },
                { unit("character_bandit", 8, 8) })
            local pu, ku, bandit = c.units[1], c.units[2], c.units[3]
            -- Park the bandit far down the order so the priest's own turn cost sets the rebase.
            pu.initiative, ku.initiative, bandit.initiative = 0, 20, 50
            openTurn(c, pu)

            local sword = knight.inventory[1]
            local full = Combat.abilityCost(ku, sword.activeAbility).amount
            local clock0 = c.clock

            assert(Combat.useItem(c, pu, priest.inventory[1], ku.x, ku.y), "the priest quickens the knight")
            assert(Status.has(ku, "status_hasted"), "the knight is hasted")
            assert(Combat.abilityCost(ku, sword.activeAbility).amount == math.floor(full / 2 + 0.5),
                "and everything it casts costs half as much")

            -- Haste cut the knight's 20 down to 10; ending the priest's turn then rebased the whole
            -- field by the ticks that elapsed, so back that out to see the halving on its own.
            local elapsed = c.clock - clock0
            assert(ku.initiative == 10 - elapsed,
                "its current initiative was halved (expected " .. (10 - elapsed) .. ", got " .. ku.initiative .. ")")
        end,
    },
    {
        name = "Haste halves the initiative a walk charges, but not how far the walk can go",
        fn = function()
            -- Archer (movement 4, less 1 for its leather armor = 3) walks three tiles of open
            -- ground: a raw path cost of 3, which endTurn folds in as elapsed clock.
            local function walkCost(hasted)
                local c = Combat.new(arena(8, 8), { unit("character_archer", 1, 1) }, {})
                local archer = c.units[1]
                if hasted then Status.apply(c, archer, "status_hasted") end
                openTurn(c, archer)
                local reach = Combat.reachable(c, archer)
                local ok, cost = Combat.moveUnit(c, archer, 1, 4)
                assert(ok, "the 3-tile move succeeds")
                return cost, reach
            end

            local plain, plainReach = walkCost(false)
            local quick, quickReach = walkCost(true)
            assert(plain == 3, "an unhasted 3-tile walk charges 3 initiative, got " .. plain)
            assert(quick == 2, "a hasted one charges half (3 * 0.5, rounded), got " .. quick)

            -- Reach is untouched: Haste buys time, not distance.
            local function count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end
            assert(count(plainReach) == count(quickReach),
                "Haste must not widen the reachable set (" .. count(plainReach)
                .. " vs " .. count(quickReach) .. ")")
        end,
    },
    {
        name = "a cost multiplier never discounts a reservation",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_mage", 1, 1) }, { unit("character_bandit", 8, 8) })
            local mage = c.units[1]
            local ab = { cost = { stat = "mana", amount = 20 }, reserve = { stat = "mana", percent = 0.25 } }
            local reserveBefore = Combat.abilityReserve(mage, ab).amount

            Status.apply(c, mage, "status_hasted")
            assert(Combat.abilityCost(mage, ab).amount == 10, "the price is halved")
            assert(Combat.abilityReserve(mage, ab).amount == reserveBefore,
                "but a commitment is not a price -- it is untouched")
        end,
    },
    {
        name = "Boots of Speed widen the reachable set without touching the base stat",
        fn = function()
            local knight = Character.instantiate("character_knight")
            knight.inventory = {} -- drop the chainmail, whose -1 movement would muddy the comparison
            local c = Combat.new(arena(8, 8), { unit(knight, 4, 4) }, { unit("character_bandit", 8, 8) })
            local u = c.units[1]
            local base = Combat.moveBudget(u)

            Character.addItem(knight, Item.instantiate("utility_boots_of_speed"))
            Combat.applyPassives(c)
            assert(Combat.moveBudget(u) == base + 1, "the boots grant a space")
            assert(knight.stats.movement == base, "and the character's own stat never drifts")
        end,
    },
}
