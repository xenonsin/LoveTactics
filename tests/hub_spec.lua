-- Tests for the hub-city data layer: building registry discovery, ordering and
-- prestige-based unlocking, quest discovery and availability filtering, and
-- blueprint immutability.

local Building = require("models.building")
local Quest = require("models.quest")
local Player = require("models.player")

-- Quest.available filters on the whole player (standing, sponsor-quest gates, completed quests), so
-- specs build a throwaway player pinned to the standing under test.
--
-- Standing is a COUNT of finished quests now (Player.standing) rather than a stored number, so it is
-- built rather than assigned. Synthetic ids: one that is not in Quest.defs moves the count and nothing
-- else, where a real id would drag its sponsor into Quest.sponsorProgress and open a shelf.
local function standingOf(n, ...)
    local done = {}
    for i = 1, math.max(0, (n or 1) - 1) do done["_standing_filler_" .. i] = true end
    -- Real quest ids on top of the filler, for a case that needs BOTH a standing and a specific quest
    -- finished (a quest-gated door). Passed separately because the two do different jobs: the filler
    -- only moves the count, these are looked up.
    for _, id in ipairs({ ... }) do done[id] = true end
    return done
end

local function playerAt(standing)
    local p = Player.new()
    p.completedQuests = standingOf(standing)
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
            assert(list[1].id == "the_gate", "the Gate should sort first: it is the city's front door")
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

            local before = findIn(Building.list({ completedQuests = standingOf(9) }), "dueling_grounds")
            assert(before, "the dueling grounds should be listed even while shut")
            assert(before.locked, "no amount of prestige should open a quest-gated door")

            local after = findIn(
                Building.list({ completedQuests = standingOf(1, "quest_colosseum_slot_01") }),
                "dueling_grounds")
            assert(not after.locked, "finishing the debut should open it, at any prestige")

            -- And a bare prestige number -- what every older caller passes -- cannot open one,
            -- because it has no way to know.
            assert(findIn(Building.list(9), "dueling_grounds").locked,
                "a prestige number alone should never open a quest gate")
        end,
    },
    {
        -- A HOUSE OPENS WHEN ITS CIRCLE FALLS, and this replaced the campaign's two-quest opening
        -- funnel. Those seven doors were gated on `unlockPrestige` and an `unlockQuest`, both reading
        -- the completed-quest count -- which is parked at zero forever now that the board is retired, so
        -- as written they were seven cards that could never open.
        --
        -- What they open on instead is the thing the mode already counts: each house IS one of the seven
        -- sins (models/descent.lua's SINS carries the join), so putting a circle's general down credits
        -- `player.standing[vendorId]` and the shelf appears in the city. That is what makes the city grow
        -- as the company goes deeper, and what brings most of the game's economy back online.
        --
        -- The QUEST GATE IS IGNORED for these rather than satisfied, which is the half worth pinning:
        -- honouring an `unlockQuest` naming a quest nobody can finish would keep the door shut whatever
        -- the player did underground.
        name = "each of the seven houses opens on its own circle, and on nothing else",
        fn = function()
            local Descent = require("models.descent")

            local function findIn(list, id)
                for _, b in ipairs(list) do if b.id == id then return b end end
            end

            for _, sin in ipairs(Descent.SINS) do
                local def = Building.defs[sin.vendor]
                assert(def, sin.id .. "'s house has no building: " .. tostring(sin.vendor))
                assert(def.unlockCircle, sin.vendor .. " is not gated on its circle")

                -- Shut with nothing beaten, however decorated the company is otherwise. Standing 20
                -- would have opened every prestige gate in the city.
                local cold = { completedQuests = standingOf(20) }
                assert(findIn(Building.list(cold), sin.vendor).locked,
                    sin.vendor .. " opened without its circle being beaten")

                -- ...and open the moment that circle is credited, and only that one.
                local warm = { completedQuests = standingOf(1), standing = { [sin.vendor] = 1 } }
                assert(not findIn(Building.list(warm), sin.vendor).locked,
                    sin.vendor .. " stayed shut with its circle beaten")
                for _, other in ipairs(Descent.SINS) do
                    if other.vendor ~= sin.vendor then
                        assert(findIn(Building.list(warm), other.vendor).locked,
                            "beating " .. sin.id .. " opened " .. other.vendor .. " as well")
                    end
                end
            end
        end,
    },
    {
        -- THE CITY HAS ONE DOOR AND IT GOES DOWN. The prologue ends at the capital, the guard points
        -- the party at the Adventurers' Guild, and a sponsor gets to them first
        -- (conversation_prologue_sponsor) -- so the Quest Board is retired and the Gate stands in its
        -- slot. This case is the inverse of the one it replaced, which asserted that no building could
        -- ever name a `state`.
        --
        -- RETIRED, NOT DELETED, and that distinction is what the second half pins: the board's
        -- blueprint, every quest, the calendar and the biome windows are all still on disk and
        -- untouched. Bringing the campaign back is removing one entry from Building.RETIRED, and this
        -- fails loudly if somebody ever "tidies up" by deleting the data instead.
        name = "the city's front door is the Gate, and the board is parked rather than cut",
        fn = function()
            local gate, board
            for _, b in ipairs(Building.list(1)) do
                if b.id == "the_gate" then gate = b end
                if b.id == "quest_board" then board = b end
            end
            assert(gate, "the Gate is a card in the city")
            assert(gate.state == "gate", "and it opens a whole screen rather than a pop-up")
            assert(not gate.locked, "the city's only door is never gated")
            assert(board == nil, "the Quest Board is retired from the city")

            -- ...but still entirely there, which is the whole point of parking it.
            assert(Building.defs.quest_board, "the board's blueprint must survive being retired")
            assert(Building.RETIRED.quest_board, "and it is the retirement that hides it, not a deletion")
            assert(next(Quest.defs) ~= nil, "the campaign's quests are still on disk")
            assert(Building.defs.draft_yard == nil, "the Draft Yard left the city with Draft")
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
        name = "Quest.available gates on prestige AND standing, not one or the other",
        fn = function()
            -- THIS CASE HAS BEEN REVERSED TWICE, so it is worth saying which way it points and why.
            -- The prestige gate came off while the descent was the campaign's progression engine:
            -- levels came from depth then, so asking the board about prestige asked a question it could
            -- not help the player answer. The descent is a separate game mode now (states/descent.lua),
            -- it banks nothing, and the campaign levels off finished quests again -- so the gate is back,
            -- and without it every house's opening leg sat on the board of a brand new save at once.
            --
            -- A chain HEAD is the thing to check -- every sin quest after the first chains off the one
            -- before it, so a later slot would be testing the chain instead of the gate.
            local function boardHas(player, id)
                for _, q in ipairs(Quest.available(player)) do
                    if q.id == id then return true end
                end
                return false
            end

            -- The Undercroft's line asks for prestige 3 and its door opens at 3. A starting company has
            -- neither, and must not be shown work it cannot take.
            assert(not boardHas(playerAt(1), "quest_undercroft_slot_01"),
                "a line whose entry prestige is unmet must stay off the board")
            assert(boardHas(playerAt(3), "quest_undercroft_slot_01"),
                "...and appear once the company is far enough along for it")

            -- The Colosseum opens at 1: the campaign has to start somewhere, and that somewhere is on
            -- the board from the first visit.
            assert(boardHas(playerAt(1), "quest_colosseum_slot_01"),
                "the opening line must be available to a company that has done nothing yet")

            -- The other gate still holds independently: the SECOND leg wants the first one done, at any
            -- level. Prestige opens a line; standing walks it.
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
        name = "the Gate Below waits for all seven generals before it takes a row on the board",
        fn = function()
            local p = playerAt(10)
            p.completedQuests.quest_colosseum_slot_10 = true

            local function gate()
                for _, q in ipairs(Quest.available(p)) do
                    if q.id == "quest_the_gate_below" then return q end
                end
                return nil
            end

            -- A locked entry rides along under EVERY ground (Quest.board), so a card shown early is a
            -- row the player cannot press repeated across the whole travel row, every morning. One
            -- general down does not earn that; the fragments do, and it takes seven to name a place.
            assert(not gate(), "one general down must not put the Gate Below on the board")

            for _, id in ipairs(Quest.defs.quest_the_gate_below.hintQuests) do
                p.completedQuests[id] = true
            end
            local entry = gate()
            assert(entry, "seven generals down must put it there")
            assert(entry.locked, "and it is locked -- the day he lands is what opens it")
            assert(entry.keysHeld == 7 and entry.keysNeeded == 7,
                string.format("the count reads 7 of 7, got %s of %s",
                    tostring(entry.keysHeld), tostring(entry.keysNeeded)))
            -- The dead generals' fragments, so the pane recites a place instead of the fallback.
            assert(entry.hints and #entry.hints == 7,
                "the finished prerequisites owe the board their location fragments")
        end,
    },
    {
        name = "blueprints are untouched after list/available",
        fn = function()
            Building.list(1)
            Quest.available(playerAt(3))
            assert(Building.defs.quest_board.locked == nil, "building blueprint mutated")
            -- Read off the registry rather than restated: this case is about a blueprint not being
            -- mutated by being listed, and it should not also be asserting what the card is called.
            local named = Building.defs.quest_board.name
            Building.list(1)
            assert(Building.defs.quest_board.name == named, "building name changed")
            assert(Quest.defs.quest_colosseum_slot_03.id == nil, "quest blueprint mutated")
        end,
    },
}
