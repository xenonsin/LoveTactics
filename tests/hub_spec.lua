-- Tests for the hub-city data layer: building registry discovery, ordering and
-- prestige-based unlocking, quest discovery and availability filtering, and
-- blueprint immutability.

local Building = require("models.building")
local Quest = require("models.quest")
local Player = require("models.player")

-- Quest.available filters on the whole player (prestige, sponsor-quest gates, completed quests),
-- so specs build a throwaway player pinned to the prestige under test.
local function playerAt(prestige)
    local p = Player.new()
    p.prestige = prestige
    return p
end

return {
    {
        name = "building registry discovers def files by filename",
        fn = function()
            assert(Building.defs.quest_board, "quest_board missing")
            assert(Building.defs.armory, "armory missing")
            assert(Building.defs.alchemist, "alchemist missing")
            assert(Building.defs.cafe, "cafe missing")
        end,
    },
    {
        name = "Building.list is sorted by order",
        fn = function()
            local list = Building.list(1)
            for i = 2, #list do
                assert(list[i - 1].order <= list[i].order,
                    "list not sorted at index " .. i)
            end
            assert(list[1].id == "quest_board", "quest_board should sort first")
        end,
    },
    {
        name = "Building.list computes locked from prestige",
        fn = function()
            for _, b in ipairs(Building.list(1)) do
                -- A quest-gated door is a separate question, asked below; a bare prestige number
                -- cannot answer it, so those are locked here whatever their threshold.
                if not b.unlockQuest then
                    assert(b.locked == (1 < b.unlockPrestige),
                        b.id .. " locked flag wrong at prestige 1")
                end
            end
        end,
    },
    {
        -- Some doors are opened by a story rather than by getting richer: the Dueling Grounds are
        -- there because you once stood on the sand, not because you can afford them.
        name = "a quest-gated building stays shut until that quest is done",
        fn = function()
            local function findIn(list, id)
                for _, b in ipairs(list) do
                    if b.id == id then return b end
                end
            end

            local before = findIn(Building.list({ prestige = 9, completedQuests = {} }), "dueling_grounds")
            assert(before, "the dueling grounds should be listed even while shut")
            assert(before.locked, "no amount of prestige should open a quest-gated door")

            local after = findIn(
                Building.list({ prestige = 1, completedQuests = { quest_colosseum_slot_01 = true } }),
                "dueling_grounds")
            assert(not after.locked, "finishing the debut should open it, at any prestige")

            -- And a bare prestige number -- what every older caller passes -- cannot open one,
            -- because it has no way to know.
            assert(findIn(Building.list(9), "dueling_grounds").locked,
                "a prestige number alone should never open a quest gate")
        end,
    },
    {
        -- Building.list copies blueprint fields one at a time, so a field it forgets reads as nil at
        -- runtime and the door silently opens the placeholder panel instead of the mode.
        name = "a building that opens a whole screen carries its state through the list",
        fn = function()
            local yard
            for _, b in ipairs(Building.list(1)) do
                if b.id == "draft_yard" then yard = b end
            end
            assert(yard, "draft_yard missing from the city")
            assert(not yard.locked, "the Draft Yard is ungated")
            assert(yard.state == "draft", "the Draft Yard should name states/draft.lua")
            assert(yard.panel == nil, "a state door has no pop-up panel")
        end,
    },
    {
        name = "quest registry discovers def files by filename",
        fn = function()
            assert(Quest.defs.quest_bastion_slot_01, "quest_bastion_slot_01 missing")
            assert(Quest.defs.quest_colosseum_slot_03, "warlord_keep missing")
        end,
    },
    {
        name = "Quest.available gates on STANDING, and no longer on prestige",
        fn = function()
            -- This case used to assert the opposite, and the reversal is the point of the change.
            -- Prestige was the campaign's single currency of progress; levels come from DEPTH now
            -- (Descent.extract), earned in the descent rather than at this board. So a prestige gate
            -- here asked a question the board could no longer help the player answer.
            --
            -- A chain HEAD is the thing to check -- every sin quest after the first chains off the one
            -- before it, so a later slot would be testing the chain instead of the gate.
            local function boardHas(player, id)
                for _, q in ipairs(Quest.available(player)) do
                    if q.id == id then return true end
                end
                return false
            end

            assert(boardHas(playerAt(1), "quest_undercroft_slot_01"),
                "a line's opening leg is on the board from the start now -- nothing about the " ..
                "company's level should hide it")

            -- ...and the honest gate still holds: the SECOND leg wants the first one done. What
            -- opens a house's work is how far in you are with that house, which is the one question
            -- the board can still answer.
            assert(not boardHas(playerAt(20), "quest_undercroft_slot_02"),
                "slot 2 must stay off the board until slot 1 is done, whatever the company's level")
        end,
    },
    {
        -- The board shows a locked card only when the quest ASKS to be seen locked (`showLocked`),
        -- which the Gate Below alone sets. The rule used to be inferred from holding one key of
        -- several, and that swept in all 21 discipline capstones -- they name two gates apiece, carry
        -- no `gateHint` between them, and so recited the fragments pane's "the generals know where"
        -- fallback at a player whose real answer was a two-quest checklist. A capstone is advertised
        -- on its parent vendor's shelf instead, where the lock names the class still missing.
        name = "a quest that has not asked to be shown locked is hidden, not locked",
        fn = function()
            -- One key of several capstones (the Colosseum's first subclass gate), and prestige past
            -- every gate, so anything willing to show locked would be on the board here.
            local p = playerAt(10)
            p.completedQuests.quest_colosseum_slot_03 = true

            for _, q in ipairs(Quest.available(p)) do
                assert(not q.locked or Quest.defs[q.id].showLocked,
                    q.id .. " is shown locked without asking to be -- see Quest.available")
            end

            local seen = {}
            for _, q in ipairs(Quest.available(p)) do seen[q.id] = true end
            assert(not seen.quest_colosseum_the_fighting_cellar,
                "a capstone one key short belongs off the board, not on it wearing a riddle")
        end,
    },
    {
        name = "the Gate Below still counts its keys on the board from the first general down",
        fn = function()
            local p = playerAt(10)
            p.completedQuests.quest_colosseum_slot_10 = true

            local gate
            for _, q in ipairs(Quest.available(p)) do
                if q.id == "quest_the_gate_below" then gate = q end
            end
            assert(gate, "one general down must put the Gate Below on the board")
            assert(gate.locked, "and it is locked -- six keys are still missing")
            assert(gate.keysHeld == 1 and gate.keysNeeded == 7,
                string.format("the count reads 1 of 7, got %s of %s",
                    tostring(gate.keysHeld), tostring(gate.keysNeeded)))
            -- The dead general's fragment, so the pane has something to recite instead of the fallback.
            assert(gate.hints and #gate.hints == 1,
                "the finished prerequisite owes the board its location fragment")
        end,
    },
    {
        name = "blueprints are untouched after list/available",
        fn = function()
            Building.list(1)
            Quest.available(playerAt(3))
            assert(Building.defs.quest_board.locked == nil, "building blueprint mutated")
            -- The card in this slot is the Gate now (the descent's front door); the FILE keeps its
            -- old name so the building order and every reference to it stay put. What this case is
            -- about is that a blueprint is not mutated by being listed, so it reads the name off the
            -- registry rather than restating it -- which is the shape it should have had all along.
            local named = Building.defs.quest_board.name
            Building.list(1)
            assert(Building.defs.quest_board.name == named, "building name changed")
            assert(Quest.defs.quest_colosseum_slot_03.id == nil, "quest blueprint mutated")
        end,
    },
}
