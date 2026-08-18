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
                -- A door gated on a deed -- a quest, a circle -- is a separate question, asked below.
                -- A bare prestige number cannot answer either, so those are locked here whatever their
                -- threshold and this case has nothing to say about them.
                if not (b.unlockQuest or Building.defs[b.id].unlockErrand) then
                    assert(b.locked == (1 < b.unlockPrestige),
                        b.id .. " locked flag wrong at prestige 1")
                end
            end
        end,
    },
    {
        -- Some doors are opened by a deed rather than by getting richer, and `unlockQuest` is the older
        -- of the two ways to say so. NO SHIPPED BUILDING USES IT ANY MORE: it named campaign quests, the
        -- board is retired, and the last card standing on one (the Dueling Grounds) was moved onto a
        -- circle for exactly that reason -- a gate naming a deed nobody can perform is a card that never
        -- opens. So the rule is pinned through a def of the spec's own rather than through the city.
        --
        -- Worth keeping despite having no subject: the gate is the campaign's, parked with the rest of
        -- it (Building.RETIRED), and bringing the board back must not find it quietly rotted.
        name = "a quest-gated building stays shut until that quest is done",
        fn = function()
            local id = "_spec_quest_gated"
            Building.defs[id] = {
                name = "Spec Hall", order = 99, x = 0, y = 0, w = 10, h = 10,
                unlockPrestige = 1, unlockQuest = "quest_colosseum_slot_01",
            }

            local function findIn(list)
                for _, b in ipairs(list) do
                    if b.id == id then return b end
                end
            end

            local ok, err = pcall(function()
                local before = findIn(Building.list({ completedQuests = standingOf(9) }))
                assert(before, "a quest-gated door should be listed even while shut")
                assert(before.locked, "no amount of prestige should open a quest-gated door")

                local after = findIn(Building.list({ completedQuests = standingOf(1, "quest_colosseum_slot_01") }))
                assert(not after.locked, "finishing the named quest should open it, at any prestige")

                -- And a bare prestige number -- what every older caller passes -- cannot open one,
                -- because it has no way to know.
                assert(findIn(Building.list(9)).locked,
                    "a prestige number alone should never open a quest gate")
            end)

            Building.defs[id] = nil -- the registry is shared; leave the city as it was found
            assert(ok, err)
        end,
    },
    {
        -- THE ONE DOOR THAT OPENS ON SOMEBODY ELSE'S WORK. The Dueling Grounds keep no shelf and post no
        -- errands, and were gated on the Colosseum debut -- a quest that went with the board, leaving
        -- the card shut forever while advertising a prestige number that was not even the gate being
        -- asked. The sand is the Colosseum's own first job now, which is the same sentence with a deed
        -- behind it that the player can actually reach.
        name = "the Dueling Grounds open on the sand, and the sand is the Colosseum's first job",
        fn = function()
            local Errand = require("models.errand")
            local function findIn(list)
                for _, b in ipairs(list) do if b.id == "dueling_grounds" then return b end end
            end

            local cold = findIn(Building.list({ completedQuests = standingOf(20) }))
            assert(cold and cold.locked, "no amount of standing should open the Dueling Grounds")

            local warm = findIn(Building.list({
                completedQuests = { [Errand.opener("colosseum")] = true } }))
            assert(warm and not warm.locked, "running the Colosseum's opener should open the Dueling Grounds")

            -- ...and it is the Colosseum's job specifically, not any house's.
            local other = findIn(Building.list({
                completedQuests = { [Errand.opener("arcanum")] = true } }))
            assert(other and other.locked, "another house's opener should not open the Dueling Grounds")
        end,
    },
    {
        -- A SHUT DOOR SAYS NOTHING, and that is the decision rather than an omission. The card carried a
        -- sentence for an afternoon -- composed off whichever gate was really being asked -- and it was
        -- the right fix for one quoting prestige, a currency the city stopped counting. It is the wrong
        -- one now: every shut shop has the SAME answer (go down, walk the floors, the work is lying on
        -- one of them), so a per-card sentence was seven copies of one instruction, and naming the house
        -- in it gave away the shop the card exists to withhold.
        --
        -- Pinned because the field going quiet is invisible: a `requirement` left on the entry would
        -- simply never be drawn, and would rot.
        name = "a shut door carries no sentence to draw",
        fn = function()
            for _, district in ipairs({ "city", "market" }) do
                for _, b in ipairs(Building.list(Player.new(), { district = district })) do
                    assert(b.requirement == nil,
                        b.id .. " carries a requirement string that nothing draws")
                end
            end
            assert(Building.requirement == nil,
                "Building.requirement has no reader; it should not have survived the card that read it")
        end,
    },
    {
        -- THE SHOPS LEFT THE CITY. Fifteen cards on one board, seven of them the same kind of thing and
        -- eleven of the fifteen shut on a fresh save, read as a wall of locked plates rather than a
        -- town. They are behind one Markets card now, on a board of their own.
        name = "every shelf is in the market and every market card is a shelf",
        fn = function()
            local Vendor = require("models.vendor")
            local p = Player.new()

            local market = Building.list(p, { district = "market" })
            assert(#market == 7, "the market holds the seven houses")
            for _, b in ipairs(market) do
                assert(b.vendor, b.id .. " is on the market board but sells nothing")
                assert(Vendor.get(b.vendor), b.id .. " names a vendor that does not exist")
            end

            -- ...and the city keeps none of them. A shelf left behind would be a second door onto the
            -- same shop, with its own unlock rule to drift.
            local city = Building.list(p, { district = "city" })
            for _, b in ipairs(city) do
                assert(not (b.vendor and Vendor.get(b.vendor) and Vendor.get(b.vendor).class),
                    b.id .. " is a class shelf still standing in the city")
            end

            -- The Markets card itself is never shut. Every stall behind it is, on a fresh save, and that
            -- is the point: the square is where you go to see what is still down there to be opened.
            -- Gating the door on its first tenant would hide the only thing it has to say early on.
            local markets
            for _, b in ipairs(city) do if b.id == "markets" then markets = b end end
            assert(markets, "the city has no door onto the market")
            assert(markets.state == "markets", "and it opens the market screen")
            assert(not markets.locked, "the Markets card is never shut")

        end,
    },
    {
        -- A HOUSE OPENS ON ITS OWN FIRST ERRAND, and this is the third gate these seven doors have had.
        --
        -- They started on `unlockPrestige` + `unlockQuest`, both reading the completed-quest count, which
        -- is parked at zero forever now the board is retired -- seven cards that could never open. They
        -- were then moved onto their CIRCLE, which could at least be beaten, and that was wrong in a
        -- subtler way: a circle sits at floor 2, 4, ... 14 in a different order every run, so six of the
        -- seven shelves were unreachable in any given descent and the only route to a class's gear was to
        -- go deeper than that gear would have carried you.
        --
        -- What opens one now is `slot_01` of its own line -- the first thing the house ever asks for,
        -- authored years ago, seated on a floor unasked because a shut house has nowhere to ask from
        -- (models/errand.lua). One ladder per house, all of it in `completedQuests`.
        --
        -- The QUEST GATE IS IGNORED for these rather than satisfied, which is the half worth pinning:
        -- honouring an `unlockQuest` naming a quest nobody can finish would keep the door shut whatever
        -- the player did underground.
        name = "each of the seven houses opens on its own first errand, and on nothing else",
        fn = function()
            local Descent = require("models.descent")
            local Errand = require("models.errand")

            local function findIn(list, id)
                for _, b in ipairs(list) do if b.id == id then return b end end
            end
            local function market(p) return Building.list(p, { district = "market" }) end

            for _, sin in ipairs(Descent.SINS) do
                local def = Building.defs[sin.vendor]
                assert(def, sin.id .. "'s house has no building: " .. tostring(sin.vendor))
                assert(def.unlockErrand, sin.vendor .. " is not gated on its opener")

                -- Shut with the opener unrun, however decorated the company is otherwise. Standing 20
                -- would have opened every prestige gate there ever was.
                local cold = { completedQuests = standingOf(20) }
                assert(findIn(market(cold), sin.vendor).locked,
                    sin.vendor .. " opened without its first errand being run")

                -- ...and open the moment that errand is finished, and only that house.
                local opener = Errand.opener(sin.vendor)
                assert(opener, sin.vendor .. " has no opener to be gated on")
                local warm = { completedQuests = { [opener] = true } }
                assert(not findIn(market(warm), sin.vendor).locked,
                    sin.vendor .. " stayed shut with its opener run")
                for _, other in ipairs(Descent.SINS) do
                    if other.vendor ~= sin.vendor then
                        assert(findIn(market(warm), other.vendor).locked,
                            "running " .. sin.id .. "'s opener opened " .. other.vendor .. " as well")
                    end
                end
            end
        end,
    },
    {
        -- THE OPENER IS SEATED WHERE IT CAN BE FOUND, which is the half of the door model that lives in
        -- the descent. A gate on work nobody is ever shown is the same dead card as a gate on prestige.
        name = "a shut house posts its opener on a floor, and an open one posts nothing",
        fn = function()
            local Descent = require("models.descent")
            local Errand = require("models.errand")

            local run = Descent.new(Player.new(), 4242)
            local p = Player.new()
            p.completedQuests = {}

            -- Every house is offered somewhere in the first lap, and the lap is a permutation rather than
            -- a roll -- a run that dealt Wrath three times would leave four shelves unreachable.
            local seen = {}
            for floor = 1, #Descent.SINS do
                local house = Descent.openerAt(run, floor)
                assert(house, "floor " .. floor .. " posts no house's work")
                assert(not seen[house], house .. " is posted twice in one lap")
                seen[house] = true
            end
            for _, sin in ipairs(Descent.SINS) do
                assert(seen[sin.vendor], sin.vendor .. " is never offered in the first seven floors")
            end

            -- ...and it is UNCORRELATED with the sins, which is the whole point: if the house on a floor
            -- were its own circle's, this would be the depth gate again with one fewer boss in front.
            local aligned = 0
            for floor = 1, #Descent.SINS do
                if Descent.openerAt(run, floor) == Descent.sinAt(run, floor).vendor then
                    aligned = aligned + 1
                end
            end
            assert(aligned < #Descent.SINS, "the openers are dealt in lock-step with the circles")

            -- The seating itself: a shut house's opener is one more end on the board, and it stops being
            -- one the moment that door is open.
            local function endsOn(player, floor)
                local sin = Descent.sinAt(run, floor)
                local ids = {}
                for _, spec in ipairs(Descent.floorObjectives(player, floor, sin, 1, false, run)) do
                    if spec.questId then ids[spec.questId] = true end
                end
                return ids
            end

            local house = Descent.openerAt(run, 1)
            local opener = Errand.opener(house)
            assert(endsOn(p, 1)[opener], house .. "'s opener is not on the floor that posts it")

            p.completedQuests[opener] = true
            assert(not endsOn(p, 1)[opener], "an open house is still posting the job that opened it")
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
