-- Tests for THE SEVEN GATES (models/descent.lua's Descent.gateState): how each circle decides whether
-- a company may fight its general.
--
-- WHY THEY EXIST. A circle owned a stratum once -- a lieutenant's stair, then hers -- and one floor per
-- circle compresses that into "walk to the end and fight the boss", which is a corridor. The gate is
-- what puts a spine back on the floor, and authoring one per sin is what keeps seven boss floors from
-- being the same boss floor seven times.
--
-- WHAT IS AT RISK is not the arithmetic of any one gate but the SET: that all seven are authored, that
-- no two ask the same kind of question, and that an unauthored one fails OPEN. The last is the one that
-- could ship silently -- a general behind a condition nobody wrote is a game that cannot be finished,
-- and nothing else in the suite would notice.
--
-- Pure model. The board counting lives in states/game.lua's stairGate and cannot be driven headlessly;
-- what is exercised here is the function it hands its measurements to.

local Descent = require("models.descent")

return {
    { name = "every circle authors a gate, and it is a kind the model knows", fn = function()
        for _, sin in ipairs(Descent.SINS) do
            local gate = Descent.gateFor(sin)
            assert(gate, sin.id .. " bars its stair with nothing at all")
            assert(Descent.GATES[gate.kind], sin.id .. " names a gate kind nothing implements: " ..
                tostring(gate.kind))
        end
    end },

    { name = "no two circles ask the same kind of question", fn = function()
        -- THE WHOLE POINT OF AUTHORING SEVEN. Two circles sharing a kind is two boss floors that play
        -- the same before their casts are dealt, which is the thing one floor per circle was in danger
        -- of producing.
        local seen = {}
        for _, sin in ipairs(Descent.SINS) do
            local kind = Descent.gateFor(sin).kind
            assert(not seen[kind], "two circles bar their stair the same way: " .. kind ..
                " on both " .. tostring(seen[kind]) .. " and " .. sin.id)
            seen[kind] = sin.id
        end
        assert(#Descent.SINS == 7, "seven circles, seven questions")
    end },

    { name = "an unauthored gate fails open", fn = function()
        -- THE ONE THAT COULD SHIP SILENTLY. A general behind a condition nobody wrote is a game that
        -- cannot be finished, and no other case in the suite would go red for it.
        assert(Descent.gateFor(nil) == nil, "no sin, no gate")
        assert(Descent.gateFor({ id = "x" }) == nil, "a sin with no gate field bars nothing")
        assert(Descent.gateState({ id = "x" }, {}).met, "and its stair is open")
        assert(Descent.gateState(nil, {}).met, "as is the bottom's, which is not a circle at all")
    end },

    { name = "sloth is open, and that is the design", fn = function()
        -- PROTECTED DELIBERATELY. The post nobody came back to is guarded by nobody: a company may walk
        -- past Acedia and go down, and fighting her is opt-in. It is the only gate that is a pure
        -- reading of its own sin, and the one a later pass is most likely to "fix".
        local sloth
        for _, sin in ipairs(Descent.SINS) do if sin.id == "sloth" then sloth = sin end end
        assert(sloth, "there is a Sloth circle")
        assert(Descent.gateFor(sloth).kind == "none", "and its stair asks nothing")
        local st = Descent.gateState(sloth, {})
        assert(st.met, "so it is open to a company that has done nothing at all")
        assert(st.label == nil, "and says nothing, because there is nothing to say")
    end },

    { name = "a counting gate reports its own progress", fn = function()
        -- A gate the player has to deduce is a puzzle. Every counting kind hands back have/need so a
        -- surface can draw "4 of 7" without knowing which gate it is looking at.
        local wrath
        for _, sin in ipairs(Descent.SINS) do if sin.id == "wrath" then wrath = sin end end
        local need = Descent.gateFor(wrath).n
        local short = Descent.gateState(wrath, { fightsCleared = need - 1 })
        assert(not short.met, "one short is still barred")
        assert(short.have == need - 1 and short.need == need, "and it says how short")
        assert(type(short.label) == "string" and #short.label > 0, "and names the condition")
        assert(Descent.gateState(wrath, { fightsCleared = need }).met, "and enough is enough")
        assert(Descent.gateState(wrath, { fightsCleared = need + 5 }).met, "as is more than enough")
    end },

    { name = "gluttony wants the floor bare, and an empty floor is bare", fn = function()
        local glut
        for _, sin in ipairs(Descent.SINS) do if sin.id == "gluttony" then glut = sin end end
        assert(not Descent.gateState(glut, { fightsCleared = 3, fightsTotal = 7 }).met,
            "three of seven leaves something alive")
        assert(Descent.gateState(glut, { fightsCleared = 7, fightsTotal = 7 }).met,
            "and seven of seven does not")
        -- A floor that seated no fights at all is already bare. The alternative -- barring a stair
        -- against a condition the board never gave the player a way to meet -- is a softlock.
        assert(Descent.gateState(glut, { fightsCleared = 0, fightsTotal = 0 }).met,
            "a floor with nothing on it is a floor with nothing left on it")
    end },

    { name = "envy wants you carrying something, and pride wants you proven", fn = function()
        local envy, pride
        for _, sin in ipairs(Descent.SINS) do
            if sin.id == "envy" then envy = sin elseif sin.id == "pride" then pride = sin end
        end
        assert(not Descent.gateState(envy, { carrying = 0 }).met, "she does not come out for nothing")
        assert(Descent.gateState(envy, { carrying = 99 }).met, "and a full mule is worth wanting")
        -- Pride reads what the COMPANY has done, ever -- not this run's. A tally that reset with the
        -- expedition would make her gate unreachable in a mode that resets on every extraction.
        assert(not Descent.gateState(pride, { sealed = 0 }).met, "she will not fight the unproven")
        assert(Descent.gateState(pride, { sealed = 99 }).met, "and will fight somebody who has")
    end },

    { name = "the toll is a share, never more than is carried, and never nothing", fn = function()
        local greed
        for _, sin in ipairs(Descent.SINS) do if sin.id == "greed" then greed = sin end end
        assert(Descent.tollFor(greed, 0) == 0, "a company carrying nothing is charged nothing")
        for carried = 1, 20 do
            local due = Descent.tollFor(greed, carried)
            assert(due >= 1, "anything carried is worth something to her: " .. carried)
            assert(due <= carried, "and she never asks for more than is there: " .. carried ..
                " carried, " .. due .. " due")
        end
        -- A bigger bag costs more, which is the whole reason the price is a share.
        assert(Descent.tollFor(greed, 16) > Descent.tollFor(greed, 4), "a fat mule pays properly")
        -- ...and only Greed has one.
        for _, sin in ipairs(Descent.SINS) do
            if sin.id ~= "greed" then
                assert(Descent.tollFor(sin, 10) == 0, sin.id .. " does not take a toll")
            end
        end
    end },

    { name = "greed's stair opens once it has been paid, and not before", fn = function()
        local greed
        for _, sin in ipairs(Descent.SINS) do if sin.id == "greed" then greed = sin end end
        assert(not Descent.gateState(greed, { paid = false }).met, "unpaid is shut")
        assert(Descent.gateState(greed, { paid = true }).met, "paid is open")
    end },

    { name = "a warded circle seats its lieutenant as an end of its own", fn = function()
        -- The gate that is a BODY. She held a stair two floors up when a circle owned a stratum; with
        -- one floor per circle she stands on this one, at her own dead end, and beating her is what
        -- opens the way down.
        local lust
        for _, sin in ipairs(Descent.SINS) do if sin.id == "lust" then lust = sin end end
        assert(Descent.gateFor(lust).kind == "ward", "Lust is the warded circle")

        local ends = Descent.floorObjectives(nil, 1, lust, 3, true)
        local ward
        for _, spec in ipairs(ends) do if spec.wardFor then ward = spec end end
        assert(ward, "her floor seats a ward end beside the stair")
        assert(ward.wardFor == lust.id, "and it names the circle it belongs to")
        assert(#ward.composition({}) >= 1, "with a body actually standing on it")
        -- It settles nothing on a shelf, so the errand payout must never see it as work.
        assert(ward.questId == nil, "a ward is not an errand and pays no purse")

        -- ...and a circle with a different gate seats none, or every floor would carry a spare boss.
        local glut
        for _, sin in ipairs(Descent.SINS) do if sin.id == "gluttony" then glut = sin end end
        for _, spec in ipairs(Descent.floorObjectives(nil, 1, glut, 3, true)) do
            assert(not spec.wardFor, "an unwarded circle seats no ward")
        end
        -- Nor does a floor with no general on it, whatever the circle's gate says.
        for _, spec in ipairs(Descent.floorObjectives(nil, 1, lust, 3, false)) do
            assert(not spec.wardFor, "a floor she is not standing on has no ward to break")
        end
    end },

    { name = "a ward wears a mark of its own on the board", fn = function()
        -- THE BUG THIS PINS. A ward is the one end that carries no quest id, and the cell used to carry
        -- nothing to tell it apart -- so states/game.lua matched the lieutenant's tile to the STAIR's
        -- spec, fought the general on it, and opened a second way down when she fell. The mark is what
        -- the board hands back, and it has to survive being put away and taken out again with it.
        local Overworld = require("models.overworld")
        local lust
        for _, sin in ipairs(Descent.SINS) do if sin.id == "lust" then lust = sin end end
        local ends = Descent.floorObjectives(nil, 1, lust, 3, true)

        local function wards(grid)
            local n, mark = 0, nil
            for y = 1, grid.rows do
                for x = 1, grid.cols do
                    local e = grid.cells[y][x].encounter
                    if e and e.wardFor then n, mark = n + 1, e.wardFor end
                end
            end
            return n, mark
        end

        local grid = Overworld.generate({
            biome = lust.biome, cols = 11, rows = 11, seed = 4242, keyCount = 0,
            encounterCount = { min = 6, max = 6 },
            encounters = { { kind = "combat", weight = 1 } },
            objectives = ends,
        })
        local n, mark = wards(grid)
        assert(n == 1, "her floor stands exactly one ward on it, not " .. n)
        assert(mark == lust.id, "and it names the circle it bars: " .. tostring(mark))
        assert(not (grid.objective and grid.objective.wardFor),
            "the floor's END is the stair, never the ward standing beside it")

        local back = Overworld.fromSnapshot(grid:snapshot())
        local n2, mark2 = wards(back)
        assert(n2 == 1 and mark2 == lust.id, "and a floor put away comes back still knowing which end is which")
    end },

    { name = "a ward pays nothing of the general's", fn = function()
        -- What beating the doorkeeper does is UNBAR the stair. The piece the guardian was carrying, the
        -- house stock behind it and the circle's own credit all belong to the body on the stair -- and
        -- the victory screen must not promise any of it for the fight two dead ends away.
        local Player = require("models.player")
        local player = Player.new()
        local run = Descent.new(player, 7)
        local lust
        for _, sin in ipairs(Descent.SINS) do if sin.id == "lust" then lust = sin end end
        local ends = Descent.floorObjectives(nil, 1, lust, 3, true)
        local ward
        for _, spec in ipairs(ends) do if spec.wardFor then ward = spec end end
        assert(Descent.objectiveReward(player, run, ward) == nil, "a ward names no reward at all")
        assert(Descent.objectiveReward(player, run, ends[1]), "and the stair beside it still pays")
    end },

    { name = "the toll ledger rides the run", fn = function()
        -- A company that paid, climbed out and came back down must not be billed twice for the stair it
        -- already bought -- and the key is a string for the reason `floors` is (Save.encode round-trips
        -- a numeric key inconsistently).
        local Save = require("models.save")
        local run = Descent.new(nil, 7)
        run.tollPaid = { ["3"] = true }
        local back = Descent.restore(Save.decode("return " .. Save.encode(Descent.snapshot(run), 0)))
        assert(back.tollPaid and back.tollPaid["3"] == true, "a paid stair stays paid across a resume")
        local fresh = Descent.restore(Save.decode("return " .. Save.encode(Descent.snapshot(Descent.new(nil, 7)), 0)))
        assert(fresh.tollPaid == nil, "and a run that has paid nothing carries no ledger at all")
    end },
}
