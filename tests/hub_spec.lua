-- Tests for the hub-city data layer: building registry discovery, ordering and
-- prestige-based unlocking, quest discovery and availability filtering, and
-- blueprint immutability.

local Building = require("models.building")
local Quest = require("models.quest")
local Player = require("models.player")

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
            assert(Building.defs.the_gate, "the_gate missing")
            assert(Building.defs.armory, "armory missing")
            assert(Building.defs.market, "market missing")
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
            -- Every gate that is a DEED rather than a threshold (models/building.lua). Each is a
            -- separate question asked below, and a bare prestige number cannot answer any of them, so a
            -- door on one is locked here whatever its threshold and this case has nothing to say about
            -- it. Listed rather than spelled out one by one, so a sixth kind of deed added to the model
            -- and forgotten here fails loudly instead of quietly widening what this case claims.
            local deeds = { "unlockQuest", "unlockDepth", "unlockWound",
                            "unlockUnidentified" }
            for _, b in ipairs(Building.list(1)) do
                local def = Building.defs[b.id]
                local onDeed = false
                for _, field in ipairs(deeds) do
                    if def[field] then onDeed = true end
                end
                if not onDeed then
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
        -- THE OPENER IS SEATED WHERE IT CAN BE FOUND, which is the half of the door model that lives in
        -- the descent. A gate on work nobody is ever shown is the same dead card as a gate on prestige.
        name = "a shut house posts its opener on a floor, and an open one posts nothing",
        fn = function()
            local Descent = require("models.descent")
            local Errand = require("models.errand")

            local run = Descent.new(Player.new(), 4242)
            local p = Player.new()
            p.completedQuests = {}

            -- EVERY HOUSE IS OFFERED IN THE FIRST FEW FLOORS, and exactly once. An opener hands over slot 0,
            -- which is gear balanced for these floors -- so a door posted deeper would be paying out kit
            -- for ground the company had already walked past (models/descent.lua's Descent.openersAt).
            -- The deal is a permutation rather than a roll: one that dealt Wrath three times would leave
            -- four shelves unreachable.
            local seen = {}
            for floor = 1, Descent.OPENER_FLOORS do
                for _, house in ipairs(Descent.openersAt(run, floor)) do
                    assert(not seen[house], house .. " is posted twice")
                    seen[house] = true
                end
            end
            for _, sin in ipairs(Descent.SINS) do
                assert(seen[sin.vendor], sin.vendor .. " is never offered in the first circle")
            end
            for floor = Descent.OPENER_FLOORS + 1, Descent.FLOORS do
                assert(#Descent.openersAt(run, floor) == 0, "floor " .. floor .. " posts a door")
            end

            -- ...and no floor of the circle carries the whole city. A shallow floor carves about seven
            -- and a half dead ends and the stair takes one, so seven doors on one board would be seating
            -- ends the generator has to degrade onto shared ground.
            for floor = 1, Descent.OPENER_FLOORS do
                assert(#Descent.openersAt(run, floor) < #Descent.SINS,
                    "floor " .. floor .. " carries every door in the game")
            end

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

            local house = Descent.openersAt(run, 1)[1]
            local opener = Errand.opener(house)
            assert(endsOn(p, 1)[opener], house .. "'s opener is not on the floor that posts it")

            p.completedQuests[opener] = true
            assert(not endsOn(p, 1)[opener], "an open house is still posting the job that opened it")
        end,
    },
    -- ("the city's front door is the Gate, and the board is parked rather than cut" stood here. It
    -- pinned the board as RETIRED-not-deleted: its blueprint still on disk, hidden by one entry in
    -- Building.RETIRED, so bringing the campaign back was a one-line change. The board is CUT now --
    -- panel, blueprint, Quest.available, Quest.board and the season table -- so there is no parked
    -- thing left to assert. The Gate standing alone in the plaza is covered by the case below, which
    -- counts the doors the city opens on.)
    {
        -- THE CITY GROWS ON WHAT THE COMPANY HAS DONE. Five of the eight cards on the plaza do nothing
        -- on a fresh save -- there is no bone to set, no shelf to browse, no supper worth buying for a
        -- road nobody has walked and nothing in the bag to forge -- so each arrives on the deed that
        -- gives it a job. Pinned card by card, because the whole value of the staging is the ORDER.
        name = "the plaza opens on two doors, and the rest arrive on the deeds that give them work",
        fn = function()
            local Descent = require("models.descent")
            local Errand = require("models.errand")
            local Wound = require("models.wound")

            local function shut(who, id)
                for _, b in ipairs(Building.list(who, { district = "city" })) do
                    if b.id == id then return b.locked end
                end
                error(id .. " is not a card in the city at all")
            end

            -- A FRESH SAVE OPENS ON THREE: hire somebody, look at what they carry, go down.
            local fresh = Player.new()
            local open = {}
            for _, b in ipairs(Building.list(fresh, { district = "city" })) do
                if not b.locked then open[#open + 1] = b.id end
            end
            table.sort(open)
            -- Three, not four: the roll was a card of its own for a while and is a tab of the Armory
            -- now (ui/jobs_editor.lua), which is the same door the question was always behind.
            assert(table.concat(open, ",") == "armory,market,the_gate",
                "a fresh city opens on the armory, the market and the stair; got " ..
                table.concat(open, ", "))

            -- THE INN, on the first wound. Setting a bone is the only thing it does, so a company that
            -- has never had anybody go down has nothing to buy in there.
            assert(shut(fresh, "the_inn"), "an unhurt company has nothing to buy at the inn")
            local hurt = Player.new()
            Wound.inflict(hurt, { { id = "character_rowan" } })
            assert(not shut(hurt, "the_inn"), "the first wound puts the sign up")
            -- ...and it stays up. The ledger empties when the stay is over and the MARK does not, or
            -- the city would lose a building the morning after it was used.
            hurt.atInn = { character_rowan = true }
            Wound.rest(hurt)
            assert(#Wound.wounded(hurt) == 0, "the ledger is clear")
            assert(not shut(hurt, "the_inn"), "a door the player has learned the way to stays put")

            -- THE CAFE at floor two and THE FORGE at floor four, off the company's own depth record.
            for id, need in pairs({ cafe = 2, forge = 4 }) do
                for floor = 0, need do
                    local p2 = Player.new()
                    Descent.reached(p2, floor)
                    assert(shut(p2, id) == (floor < need),
                        id .. " reads the wrong way with the company at floor " .. floor)
                end
            end

            -- The record is the COMPANY's rather than the run's (models/descent.lua's Descent.reached),
            -- so climbing out and going back down shallow cannot take a building away again.
            local deep = Player.new()
            Descent.reached(deep, 6)
            Descent.reached(deep, 1)
            assert(not shut(deep, "forge"), "a shallow trip must not shut a door six floors opened")

            -- NONE OF THEM IS ON A PRESTIGE GATE any more, which is the half that would rot silently:
            -- standing 20 is past every threshold this city has ever had.
            local decorated = Player.new()
            decorated.completedQuests = standingOf(20)
            for _, id in ipairs({ "the_inn", "cafe", "forge" }) do
                assert(shut(decorated, id), id .. " opened on standing rather than on its deed")
            end
        end,
    },
    {
        name = "quest registry discovers def files by filename",
        fn = function()
            assert(Quest.defs.quest_bastion_slot_01, "quest_bastion_slot_01 missing")
            assert(Quest.defs.quest_colosseum_slot_01, "quest_colosseum_slot_01 missing")
        end,
    },
    -- (Four cases stood here, all about what the BOARD would show: that Quest.available gated on
    -- prestige AND standing rather than either alone, that a quest which had not asked to be shown
    -- locked was hidden instead, that the Gate Below waited for all seven generals before taking a row,
    -- and that listing and availability left blueprints untouched.
    --
    -- Quest.available is gone with the board. The blueprint-immutability half is kept, asked of
    -- Building.list alone, because that is the mutation this file exists to catch.)
    {
        name = "blueprints are untouched after Building.list",
        fn = function()
            Building.list(3)
            local named = Building.defs.the_gate.name
            Building.list(1)
            assert(Building.defs.the_gate.name == named, "building name changed")
            assert(Building.defs.the_gate.locked == nil, "building blueprint mutated")
        end,
    },
}
