-- The bench: the four of the company who did not take the field, and the two ways they get onto it.
--
--   ROTATE     a living unit standing in the deploy zone spends its TURN to trade places
--   REINFORCE  a slot has opened (somebody fell), so filling it costs nothing
--
-- Covers the rules that are easy to get wrong and expensive to get wrong quietly:
--   * a benched member is NOT on the board or the timeline, and does not freeze the clock;
--   * a rotation costs a turn, and the body coming on inherits that bill;
--   * a rotation is refused outside your own lines, with a reason;
--   * statuses ride out and back -- falling back parks a poison rather than curing it;
--   * a withdrawal is not a death (no corpse, no allyDown tally);
--   * the field cap holds, except for the last-stand override;
--   * a party with a body still benched has NOT lost, and an empty bench still loses.
-- Pure model logic, so it runs headless.

local Character = require("models.character")
local Combat = require("models.combat")
local Status = require("models.status")
local Fixture = require("tests.support.fixture")

-- A board whose deploy zone is the two near rows, built the way Arena.build would hand one over.
local function zoneRows(cols, rows, n)
    local zone = {}
    for y = rows - (n or 2) + 1, rows do
        for x = 1, cols do zone[#zone + 1] = { x = x, y = y } end
    end
    return zone
end

-- A fight with `party` on the field, `bench` waiting, and one foe. The party stands on the home rows,
-- so it is inside the zone unless a case walks it out.
local function fight(opts)
    opts = opts or {}
    local cols, rows = 6, 6
    local partyUnits = {}
    for i, spec in ipairs(opts.party or { { "character_knight", 2, 6 } }) do
        partyUnits[i] = Fixture.unit(spec[1], spec[2], spec[3], { isolate = "mechanics" })
    end
    local c = Combat.new(Fixture.new(cols, rows), partyUnits,
        { Fixture.unit("character_bandit", 3, 1, { isolate = "mechanics" }) })
    c.deployZone = zoneRows(cols, rows, 2)
    for _, id in ipairs(opts.bench or { "character_mage" }) do
        Combat.benchUnit(c, { char = Character.instantiate(id) })
    end
    return c
end

-- Open a turn for `unit` the way the driver does, so a rotation has a turn to spend.
local function openTurn(c, unit)
    unit.initiative = 0
    for _, u in ipairs(c.units) do
        if u ~= unit and u.alive then u.initiative = math.max(u.initiative, 1) end
    end
    c.turn = { unit = unit, moved = false, moveCost = 0, startX = unit.x, startY = unit.y }
    return unit
end

return {
    {
        name = "a benched member is not on the board, the timeline, or the alive count",
        fn = function()
            local c = fight()
            assert(#c.units == 2, "only the fielded body and the foe stand on the board")
            assert(Combat.aliveCount(c, "party") == 1, "the bench is not alive on the field")
            assert(Combat.benchCount(c, "party") == 1, "but it is counted as a reserve")
            assert(Combat.benchCount(c, "enemy") == 0, "the enemy has no bench, ever")
            for _, u in ipairs(Combat.turnOrder(c)) do
                assert(u.side ~= "party" or u.char.id ~= "character_mage", "no benched unit rides the timeline")
            end
        end,
    },
    {
        name = "the clock still advances with a full bench (the rebase minimum never sees it)",
        fn = function()
            local c = fight()
            local before = c.clock
            local hero = c.units[1]
            openTurn(c, hero)
            Combat.wait(c, hero)
            assert(c.clock > before, "time passed; a bench cannot peg the minimum at 0")
        end,
    },
    {
        name = "a rotation costs a turn, and the body coming on inherits the bill",
        fn = function()
            local c = fight()
            local hero = c.units[1]
            openTurn(c, hero)
            local turns = c.turnCount
            local arrival = Combat.rotate(c, hero, 1)
            assert(arrival, "the rotation went through")
            assert(arrival.x == 2 and arrival.y == 6, "the newcomer stands where the swapper stood")
            assert(not hero.alive and hero.withdrawn, "the swapper is off the board, withdrawn")
            assert(c.turnCount == turns + 1, "a turn was spent")
            assert(c.turn == nil, "and it is over")
            assert(arrival.initiative > 0, "the newcomer waits out the turn the rotation cost")
            -- A trade, not a withdrawal: the bench is the same size, holding the other body now.
            assert(Combat.benchCount(c, "party") == 1, "the bench still holds one -- they swapped")
            assert(c.bench[1].char == hero.char, "and it is the one who fell back")
        end,
    },
    {
        name = "a rotation is refused outside your own lines, and says why",
        fn = function()
            local c = fight({ party = { { "character_knight", 3, 3 } } }) -- mid-board, out of the zone
            local hero = c.units[1]
            openTurn(c, hero)
            local ok, why = Combat.canRotate(c, hero)
            assert(not ok, "a unit out in the field cannot trade places")
            assert(type(why) == "string" and #why > 0, "and the refusal names a reason")
            local done = Combat.rotate(c, hero, 1)
            assert(done == false, "the rotation itself is refused too")
            assert(hero.alive, "and costs the unit nothing")
            assert(c.turnCount == 0, "no turn was spent on a refusal")
        end,
    },
    {
        name = "a rotation is refused with an empty bench",
        fn = function()
            local c = fight({ bench = {} })
            local hero = c.units[1]
            openTurn(c, hero)
            local ok, why = Combat.canRotate(c, hero)
            assert(not ok and why, "nobody to trade with, and it says so")
        end,
    },
    {
        name = "statuses ride out and back -- falling back parks a poison, it does not cure it",
        fn = function()
            local c = fight()
            local hero = c.units[1]
            Status.apply(c, hero, "status_poison")
            assert(Status.has(hero, "status_poison"), "precondition: the hero is poisoned")
            openTurn(c, hero)
            Combat.rotate(c, hero, 1)
            -- The hero is now the only bench entry, carrying what they walked off with.
            local entry = c.bench[1]
            assert(entry and entry.char == hero.char, "the withdrawn body is the one on the bench")
            assert(entry.statuses and next(entry.statuses), "and it took its statuses with it")

            -- Rotate them back on: the poison is still there. (The mage who came on is now the swapper,
            -- and stands in the zone, so the trade runs in reverse.)
            local mage = c.units[#c.units]
            openTurn(c, mage)
            local back = Combat.rotate(c, mage, 1)
            assert(back, "the body comes back on")
            assert(back.char == hero.char, "and it is the poisoned one")
            assert(Status.has(back, "status_poison"), "still poisoned -- a rotation is not a cleanse")
        end,
    },
    {
        name = "a withdrawal is not a death: no corpse, no body to revive, no ally-down tally",
        fn = function()
            local c = fight()
            local hero = c.units[1]
            openTurn(c, hero)
            Combat.rotate(c, hero, 1)
            assert(not hero.corpse, "a body that walked off leaves no corpse")
            assert(not hero.incapacitated, "and is not lying there waiting for a revive")
            assert(Combat.corpseAt(c, 2, 6) == nil, "there is nothing to harvest where it stood")
            assert(Combat.downedAt(c, 2, 6) == nil, "and nothing to revive")
        end,
    },
    {
        name = "reinforce is free, lands only inside the zone, and refuses a full field",
        fn = function()
            local c = fight({
                party = { { "character_knight", 1, 6 }, { "character_knight", 2, 6 },
                          { "character_knight", 3, 6 }, { "character_knight", 4, 6 } },
                bench = { "character_mage" },
            })
            assert(Combat.fieldCount(c, "party") == Combat.MAX_FIELD, "precondition: the line is full")
            local ok, why = Combat.canReinforce(c)
            assert(not ok and why, "a full line takes nobody, and says so")

            -- Fell one. The slot opens the moment the body drops.
            local fallen = c.units[1]
            fallen.alive = false
            assert(Combat.fieldCount(c, "party") == Combat.MAX_FIELD - 1, "a fallen body holds no slot")
            assert(Combat.canReinforce(c), "so a reserve may come in")

            local turns = c.turnCount
            local bad = Combat.reinforce(c, 1, 3, 3) -- mid-board, outside the zone
            assert(bad == false, "a reinforcement cannot walk in through the middle of the board")
            local unit = Combat.reinforce(c, 1, 5, 6)
            assert(unit and unit.x == 5 and unit.y == 6, "it comes in on its own ground")
            assert(c.turnCount == turns, "and costs no turn")
            assert(unit.initiative >= 0, "arriving clamped, so it cannot cut ahead of whoever is acting")
        end,
    },
    {
        name = "with nothing standing, a reserve may always come in -- the last-stand override",
        fn = function()
            local c = fight()
            c.units[1].alive = false
            assert(Combat.aliveCount(c, "party") == 0, "precondition: nothing of the player's stands")
            assert(Combat.canReinforce(c), "the bench is the difference between a rally and a wipe")
        end,
    },
    {
        name = "a party with a body still benched has not lost",
        fn = function()
            local c = fight()
            c.units[1].alive = false
            assert(Combat.aliveCount(c, "party") == 0, "precondition: the line is broken")
            assert(Combat.outcomeFor(c, "party") ~= "loss", "but the company is not beaten")
            assert(Combat.evaluate(c) ~= "loss", "and the fight reads the same way")
        end,
    },
    {
        name = "an empty bench and an empty field is still a loss",
        fn = function()
            local c = fight({ bench = {} })
            c.units[1].alive = false
            assert(Combat.outcomeFor(c, "party") == "loss", "nobody standing and nobody left to send")
        end,
    },
    {
        name = "the enemy cannot win by clearing a line the bench can replace",
        fn = function()
            local c = fight()
            c.units[1].alive = false
            assert(Combat.outcomeFor(c, "enemy") ~= "win",
                "killAll reads the party's bench too -- the far side has not finished them")
        end,
    },
    {
        name = "a summon does not count against the four-body field cap",
        fn = function()
            local c = fight()
            local wolf = Combat.addUnit(c, Character.instantiate("character_bandit"), "party", 5, 6,
                { summoned = true })
            assert(wolf, "the summon stands")
            assert(Combat.fieldCount(c, "party") == 1, "the cap counts the company, not what it conjures")
        end,
    },
    {
        name = "a battle with no deploy zone simply refuses to rotate",
        fn = function()
            local c = fight()
            c.deployZone = nil
            local hero = c.units[1]
            openTurn(c, hero)
            local ok, why = Combat.canRotate(c, hero)
            assert(not ok and why, "a duel or a scripted fight has no ground to fall back to")
        end,
    },
}
