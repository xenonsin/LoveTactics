-- THE BENCH: the bodies an arena had no room for, and the fact that nothing brings them back.
--
-- TWO MOVES USED TO. ROTATE spent a living unit's turn to trade places with a reserve, from inside the
-- deploy zone -- FALL BACK on every surface the player read. REINFORCE filled a slot a death had opened,
-- free. Both are deleted: an expedition is four (Descent.PARTY_MAX) and the board holds four
-- (Combat.MAX_FIELD), so there is never anybody off the field to send for.
--
-- WHAT IS LEFT IS STILL WORTH PINNING. `combat.bench` did not go with them -- models/encounter_battle.lua
-- still parks anybody the arena could not seat -- and the rules about what a benched body IS are the
-- ones that were expensive to get wrong quietly: it is not on the board, not on the timeline, and does
-- not freeze the clock.
--
-- AND ONE RULE INVERTED, which is why this file kept its name rather than being deleted with the moves.
-- A party with somebody benched had NOT lost, because a reserve could still be called. Combat.eliminated
-- no longer reads the bench: a body nobody can reach cannot hold a fight open, and a battle you can
-- neither win nor lose is worse than either ending. The two cases at the bottom are that reversal, kept
-- side by side with what did not change.

local Combat = require("models.combat")
local Character = require("models.character")
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
        -- THE REVERSAL. This case asserted the opposite until the ways back on were removed: a company
        -- with a body still benched had not lost, on the reasoning that "the fight is over when there is
        -- no one left to send in, not when the four who happened to be standing have fallen".
        --
        -- That reasoning was sound while somebody could be sent in. Nobody can, so a bench that once
        -- bought a rally now only buys a fight that cannot end -- the loop has nothing to hand the turn
        -- to and nothing to resolve on.
        name = "a bench nobody can reach does not hold a fight open",
        fn = function()
            local c = fight()
            for _, u in ipairs(c.units) do
                if u.side == "party" then u.alive = false end
            end
            assert(Combat.benchCount(c, "party") == 1, "somebody is still on the bench")
            assert(Combat.eliminated(c, "party"), "and the party is still eliminated")
            assert(Combat.outcomeFor(c, "party") == "loss", "which is a loss, not a stalemate")
        end,
    },
    {
        name = "clearing the line is the win it looks like, from the other side",
        fn = function()
            local c = fight()
            for _, u in ipairs(c.units) do
                if u.side == "party" then u.alive = false end
            end
            assert(Combat.outcomeFor(c, "enemy") == "win",
                "the enemy has cleared the board and there is nobody coming")
        end,
    },
}
