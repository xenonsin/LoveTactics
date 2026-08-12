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
        -- THE OPENING FUNNEL IS TWO QUESTS WIDE. Finishing the debut pays a prestige, and prestige 2
        -- used to be the whole gate on three shops -- so one quest into the campaign the player was
        -- handed the Cathedral, the Bastion and the Lodge at once, before they had run anything. All
        -- three now wait on the padded card as well (data/buildings/cathedral.lua and its neighbours).
        -- Everything at prestige 3 and up is untouched on purpose; this pins the two-quest funnel and
        -- nothing beyond it, so a later re-tier of the upper doors does not have to argue with it.
        name = "the debut alone opens no house; the padded card opens three",
        fn = function()
            local FUNNELLED = { "cathedral", "bastion", "hunters_lodge" }

            local function lockedIn(ctx, id)
                for _, b in ipairs(Building.list(ctx)) do
                    if b.id == id then return b.locked end
                end
                error("no such building listed: " .. id)
            end

            -- The state the player is actually in after the debut: one quest done, so standing 2.
            -- Standing is DERIVED from the ledger now, so these fixtures state the ledger and let the
            -- count fall out of it rather than asserting the two agree.
            local afterDebut = { completedQuests = standingOf(2, "quest_colosseum_slot_01") }
            for _, id in ipairs(FUNNELLED) do
                assert(lockedIn(afterDebut, id),
                    id .. " should still be shut one quest into the campaign")
            end

            local afterCard = { completedQuests = standingOf(3,
                "quest_colosseum_slot_01", "quest_colosseum_slot_02") }
            for _, id in ipairs(FUNNELLED) do
                assert(not lockedIn(afterCard, id), id .. " should open on the padded card")
            end

            -- THE QUEST HALF STILL BITES ON ITS OWN: standing far past the door's threshold, the card
            -- unplayed, and the Bastion stays shut.
            local standingOnly = { completedQuests = standingOf(20) }
            assert(lockedIn(standingOnly, "bastion"),
                "no amount of standing should open a door a story is supposed to open")

            -- THE STANDING HALF NO LONGER CAN, and that is a real consequence of standing becoming the
            -- quest count rather than a number a save holds independently. This case used to assert the
            -- opposite -- two quests done at prestige 1 -- which was a state a player could be in when
            -- the two gates read different sources and is now unreachable by construction: finishing
            -- the padded card IS two quests, so it necessarily carries standing 3, past the Bastion's
            -- threshold of 2. The door's two gates are no longer independent, so the AND is only doing
            -- one gate's work here. That is worth knowing rather than papering over: if the funnel is
            -- ever meant to bite in both directions again, the door needs a threshold ABOVE the quest
            -- count its own `unlockQuest` implies.
            local Building2 = require("models.building")
            local afterCardStanding = 3 -- slot_01 + slot_02
            assert(afterCardStanding >= (Building2.defs.bastion.unlockPrestige or 1),
                "fixture check: the padded card already clears the Bastion's standing threshold, which "
                .. "is why the standing half cannot be tested in isolation any more")
        end,
    },
    {
        -- THE CITY IS THE CAMPAIGN'S TOWN AND NOTHING ELSE'S. The Draft Yard and the Gate both stood
        -- here once, and both were doors onto modes that share none of the campaign's progression --
        -- which made the town read as the place all three lived. Every card is a campaign door now, so
        -- no building names a `state` and the hub has no branch for one (states/hub.lua): a card that
        -- somehow carried one would open nothing at all.
        name = "every door in the city is a campaign door, and opens a panel",
        fn = function()
            local board
            for _, b in ipairs(Building.list(1)) do
                assert(b.state == nil,
                    b.id .. " names a state, but the hub only opens panels now")
                if b.id == "quest_board" then board = b end
            end
            assert(board, "the Quest Board is the first card in the city")
            assert(board.panel == "quest_board",
                "the board's card opens the board -- it was the descent's Gate for a while")
            assert(not board.locked, "and the campaign's front door is never gated")
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
            -- Read off the registry rather than restated: this case is about a blueprint not being
            -- mutated by being listed, and it should not also be asserting what the card is called.
            local named = Building.defs.quest_board.name
            Building.list(1)
            assert(Building.defs.quest_board.name == named, "building name changed")
            assert(Quest.defs.quest_colosseum_slot_03.id == nil, "quest blueprint mutated")
        end,
    },
}
