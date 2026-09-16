-- Tests for models/errand.lua -- the seven companion postings, and the two beats that recruit one.
--
-- THIS FILE REPLACED tests/errand_spec.lua, which pinned a ladder that no longer exists: every house
-- posted a line of errands and running them climbed that house's shelf, rung by rung. The houses are
-- classes now (docs/classes.md) and a class is climbed by a BODY playing its gear
-- (Class.classLevel), so there are no lines, no rungs bought with work, and no doors.
--
-- What survived the cut is the one thing the ladder carried that had nowhere else to go: a reason to go
-- back down, said out loud, with a name attached. Seven companions stand on the first floors, each asks
-- for one piece of work, and clearing it is how they join.

local Errand = require("models.errand")
local Descent = require("models.descent")
local Player = require("models.player")
local Quest = require("models.quest")
local Save = require("models.save")
local Vendor = require("models.vendor")

local function company(done)
    local p = Player.new()
    p.completedQuests = done or {}
    return p
end

local function houses()
    local ids = {}
    for vendorId in pairs(Errand.houses()) do ids[#ids + 1] = vendorId end
    table.sort(ids)
    return ids
end

-- THE SCRIPTED COMPANION IS OUTSIDE THE ROLL, so every case below that is ABOUT the roll has to start
-- from a company that already has her: while her posting is outstanding the descent deals her onto floor
-- one and the dice are never thrown (Descent.SCRIPTED_COMPANION). A fixture that forgot this would not
-- fail loudly -- it would quietly re-test the scripted path under a name that says "roll", which is the
-- failure mode this helper exists to make impossible to reach by accident.
--
-- Named for the role rather than the body: it reads the constant, so moving the script from one house to
-- another (it was Saber's, it is Amana's) leaves every fixture below correct.
local function scriptedJoined(done)
    done = done or {}
    done[Errand.opener(Descent.SCRIPTED_COMPANION)] = true
    return done
end

return {
    {
        -- The whole roster arrives this way, so a class that names a companion and cannot post an ask
        -- for them is a body that can never be recruited -- and it would fail silently, because a
        -- posting that does not exist simply is not seated.
        name = "every class with a companion posts an ask that exists and can be fought",
        fn = function()
            local seen = 0
            for vendorId, def in pairs(Vendor.defs) do
                if def.companion then
                    local ask = Errand.opener(vendorId)
                    assert(ask, vendorId .. " names " .. def.companion .. " but posts no ask")
                    local qdef = Quest.defs[ask]
                    assert(qdef and qdef.map and qdef.map.objective,
                        ask .. " has no objective, so no floor can seat it")
                    seen = seen + 1
                end
            end
            assert(seen == 7, "seven houses, seven postings -- found " .. seen)
        end,
    },
    {
        -- WHAT THE DESCENT ACTUALLY DEALS is the set of postings that hand a body over, and it is a
        -- narrower thing than the set of houses that name one. The Bastion names Rowan and grants
        -- nobody, and gating on the NAME seated a recruitment posting at a dead end for a companion
        -- already standing in the party -- a walk, a fight, and no recruit at the end of it.
        name = "the deck is the postings that recruit, not the houses that name a body",
        fn = function()
            local houses = Errand.houses()
            assert(not houses.bastion, "the Bastion posts a recruit for a body sworn in the prologue")

            local n = 0
            for vendorId in pairs(houses) do
                n = n + 1
                local who = Errand.companionOf(vendorId)
                assert(who and Quest.defs[Errand.opener(vendorId)].rewardCharacter == who,
                    vendorId .. " is dealt but pays no character")
                assert(who == Vendor.defs[vendorId].companion,
                    vendorId .. " pays " .. who .. ", who is not the body it names")
            end
            assert(n == 6, "six of the seven houses recruit underground, got " .. n)
        end,
    },
    {
        -- The join route. Every posting hands its companion over through `rewardCharacter`, which is
        -- the path Quest.complete already walked for Saber -- Player.recruit runs before the outro, so
        -- the join banner and their first words land in one beat.
        --
        -- Rowan is the one exemption and it is authored rather than incidental: she is the player's
        -- bodyguard from the prologue, so granting her again would be a reward nobody can receive --
        -- which is why her house is not dealt at all (see the case above).
        name = "a posting hands over the companion it was met with",
        fn = function()
            assert(#houses() > 0, "nobody is dealt, so nothing below is being tested")
            for _, vendorId in ipairs(houses()) do
                local def = Quest.defs[Errand.opener(vendorId)]
                local companion = Vendor.defs[vendorId].companion
                assert(def.rewardCharacter == companion,
                    vendorId .. " posts for " .. tostring(companion)
                        .. " but pays " .. tostring(def.rewardCharacter))
            end
            assert(Quest.defs[Errand.opener("bastion")].rewardCharacter == nil,
                "Rowan joins in the prologue; the Bastion's posting must not re-grant her")
        end,
    },
    {
        -- EACH BODY SPEAKS FOR HERSELF, and the pair is required rather than preferred.
        --
        -- Two generic scenes carried all seven before this: the same three sentences under six different
        -- portraits, in the one beat that has to establish who a companion IS before the player fights
        -- beside her for the rest of the run. They are per-companion now and there is no fallback behind
        -- them (Errand.postingScene returns nil), so a missing scene is a body who cannot ask -- which
        -- is silent on the board and loud here.
        --
        -- BOTH KINDS, because the second meeting is not the first: `found` is the introduction, `asked`
        -- is walking back up to somebody who has already asked, and playing the introduction twice is
        -- the failure the split exists to stop.
        name = "every companion has her own scene, for both meetings",
        fn = function()
            local Conversation = require("models.conversation")
            for _, vendorId in ipairs(houses()) do
                local who = Errand.companionOf(vendorId)
                for _, kind in ipairs({ "found", "asked" }) do
                    local id = Errand.postingScene({ vendorId = vendorId, kind = kind })
                    assert(id == "conversation_" .. vendorId .. "_errand_" .. kind,
                        vendorId .. " has no " .. kind .. " scene of its own, got " .. tostring(id))

                    -- ...and the companion is in it. A scene that names the house but casts nobody is
                    -- the generic prose again under a per-house filename.
                    local def = Conversation.defs[id]
                    local cast = false
                    for _, entry in ipairs(def.cast or {}) do
                        if entry == who or (type(entry) == "table" and entry.id == who) then cast = true end
                    end
                    assert(cast, id .. " does not cast " .. tostring(who) .. ", who is the one asking")
                end
            end

            -- The generic pair is gone rather than kept as a safety net. A fallback that exists is a
            -- fallback something silently lands on.
            assert(not Conversation.defs.conversation_errand_found, "the generic posting scene is back")
            assert(not Conversation.defs.conversation_errand_asked, "the generic asked scene is back")
        end,
    },
    {
        -- THE BUG THIS PINS SHIPPED, AND IT PAID NOTHING WHERE IT MATTERED MOST. Every case above is
        -- about the DATA -- a house posts an ask, the ask names a body, the body is the one the house
        -- names -- and all of it was true while the mode handed over nobody at all. Clearing a companion's
        -- ask in the rift runs states/game.lua's errand payout, which called Errand.complete, paid the
        -- purse, granted the goods and played the outro. It never granted `rewardCharacter`: that lived
        -- in Quest.complete, the CAMPAIGN's payout seam, which the descent deliberately does not call.
        --
        -- So a player could meet a body at a dead end, agree, walk the floor, win the fight, watch her
        -- say she was coming with them, and climb out alone. Nothing in this file went red, because
        -- nothing in this file ever asked what the payout DID -- see the memory note about a report
        -- column no pass reads.
        --
        -- The seam is pinned rather than the caller: what has to be true is that finishing the work puts
        -- her on the roster, and that the announcement is queued for the scene that plays next.
        name = "finishing a companion's ask actually puts her on the roster",
        fn = function()
            local Conversation = require("models.conversation")
            for i = #Conversation.pendingJoins, 1, -1 do Conversation.pendingJoins[i] = nil end

            for _, vendorId in ipairs(houses()) do
                local p = company()
                p.roster = {}
                local ask = Errand.opener(vendorId)
                local who = Errand.companionOf(vendorId)
                Errand.accept(p, ask, 1)

                assert(Errand.complete(p, ask), vendorId .. "'s ask would not complete")
                -- ...and this is the line the payout was missing. Asserted through Player.recruit
                -- because that is the one route onto the roster that also queues the join banner.
                local joined = Player.recruit(p, require("models.quest").defs[ask].rewardCharacter)
                assert(joined, vendorId .. " finished its ask and handed over nobody")
                assert(joined.id == who or joined.blueprint == who or joined.name,
                    vendorId .. " handed over something that is not " .. tostring(who))

                local onRoster = false
                for _, body in ipairs(p.roster or {}) do
                    if body == joined then onRoster = true end
                end
                assert(onRoster, tostring(who) .. " was granted but is not standing in the company")
            end

            assert(#Conversation.pendingJoins == #houses(),
                "every recruit must queue a join banner for the scene that plays next")
            for i = #Conversation.pendingJoins, 1, -1 do Conversation.pendingJoins[i] = nil end

            -- AND THE CALLER, READ OFF THE SOURCE, which is the half that actually regressed. Everything
            -- above proves the seam works when something calls it, and that was already true while the
            -- payout called nothing. states/game.lua is a state file -- it switches states, draws, and
            -- cannot be driven headless -- so the only way to assert that its errand payout grants the
            -- companion is to read the line. Brittle to a rename on purpose: a rename is exactly when
            -- somebody should be made to look at this again.
            local src = love.filesystem.read("states/game.lua")
            assert(src, "states/game.lua could not be read")
            assert(src:find("Player.recruit(game.player, def.rewardCharacter)", 1, true),
                "the descent's errand payout no longer grants rewardCharacter -- a companion's ask pays "
                    .. "its purse and its goods and hands over nobody (see this case's note)")
        end,
    },
    {
        name = "an ask is outstanding until it is run, and finishing it is what joins them",
        fn = function()
            local vendorId = houses()[1]
            local ask = Errand.opener(vendorId)

            assert(not Errand.doorOpen(company(), vendorId), "nothing is done on a fresh save")
            assert(Errand.doorOpen(company({ [ask] = true }), vendorId),
                "running the ask is the whole of the question")
        end,
    },
    {
        -- The second beat. Accepting marks the ask on the floor the companion was met on and puts a row
        -- on the checklist; until then there is nothing outstanding at all, because talking is free.
        name = "accepting an ask marks it on the floor it was met on, and says so until it is done",
        fn = function()
            local p = company()
            local vendorId = houses()[1]
            local ask = Errand.opener(vendorId)

            assert(#Errand.open(p) == 0, "a company that has met nobody carries nothing")

            Errand.accept(p, ask, 2)
            local open = Errand.open(p)
            assert(#open == 1 and open[1].id == ask, "the ask is outstanding once it is taken on")
            assert(open[1].floor == 2, "and it remembers which floor to look on")
            assert(Errand.floorFor(p, vendorId) == 2, "which is what the readout asks for")

            local onTwo = Errand.onFloor(p, 2)
            assert(#onTwo == 1 and onTwo[1].id == ask, "floor two carries it")
            assert(#Errand.onFloor(p, 3) == 0, "and no other floor does")

            -- Finished is finished: the mark comes off the board rather than lingering as a row nobody
            -- can clear.
            p.completedQuests[ask] = true
            assert(#Errand.open(p) == 0, "a finished ask is not outstanding")
            assert(#Errand.onFloor(p, 2) == 0, "and its floor no longer carries it")
        end,
    },
    {
        name = "an accepted ask survives a save, floor and all",
        fn = function()
            local p = company()
            local ask = Errand.opener(houses()[1])
            Errand.accept(p, ask, 2)

            -- Through the encoder rather than the snapshot table alone: what has to survive is the
            -- written file, and a field that is snapshotted but not serialized would pass the shorter
            -- test and lose the floor on disk.
            local back = Save.restore(Save.decode("return " .. Save.encode(Save.snapshot(p), 0)))
            local open = Errand.open(back)
            assert(#open == 1 and open[1].id == ask and open[1].floor == 2,
                "an ask whose floor did not survive is an ask the player has to remember")
        end,
    },
    {
        -- ONE PER DESCENT IS THE PACING, and it is the thing this file exists to hold. It was one per
        -- FLOOR -- the six houses shuffled and dealt a body apiece onto floors one through six -- so
        -- every run met everybody on a schedule and the roster filled itself whether or not the player
        -- went looking. A roll makes one floor deeper the only way to buy another chance at a body.
        name = "a descent offers one companion at most, on one floor",
        fn = function()
            local visited = company(scriptedJoined())
            for _, vendorId in ipairs(houses()) do Player.markVendorVisited(visited, vendorId) end

            for _, seed in ipairs({ 12345, 777, 4242, 99, 31337 }) do
                local run = Descent.new(visited, seed)
                local seen = 0
                for floor = 1, Descent.FLOORS do
                    local here = Descent.openersAt(run, floor)
                    assert(#here <= 1, "floor " .. floor .. " carries " .. #here
                        .. " companions -- that is a queue, not a meeting")
                    seen = seen + #here
                end
                assert(seen <= 1, "seed " .. seed .. " deals " .. seen
                    .. " companions in one descent; the whole point is that it deals one")
                if run.companion then
                    assert(run.companion.floor >= 1 and run.companion.floor <= Descent.CIRCLE_FLOORS,
                        "dealt onto floor " .. tostring(run.companion.floor) .. ", which is not a circle")
                    assert(Errand.houses()[run.companion.house],
                        run.companion.house .. " recruits nobody and must not be dealt")
                end
            end
        end,
    },
    {
        -- A COMPANION CAN NOW JOIN ABOVE GROUND, and Errand.doorOpen has to survive it.
        --
        -- Amana joins in the prologue's Cathedral scene (states/prologue.lua), so her POSTING is never
        -- completed. Read off the quest ledger alone -- which is all this predicate used to do -- her
        -- door stays shut forever: the descent keeps standing her on floor one to be met by a company
        -- she is already in, and the deck keeps dealing the Cathedral instead of one of the six houses
        -- that still have somebody to hand over. Both bugs are silent; both are one player-visible
        -- symptom ("why is she introducing herself again?").
        name = "a companion who joined without finishing her posting still reads as joined",
        fn = function()
            local house = Descent.SCRIPTED_COMPANION
            local p = company()
            assert(not Errand.doorOpen(p, house), "nobody has joined and no posting is done")

            Player.recruit(p, Errand.companionOf(house))
            assert(Errand.doorOpen(p, house),
                "she is walking with the company, so her house has nothing left to give")
            assert(not (p.completedQuests or {})[Errand.opener(house)],
                "...and it is the ROSTER that says so -- her posting was never run")

            -- ...which is the whole point: the run must stop offering her.
            for _, seed in ipairs({ 1, 12345, 777, 4242 }) do
                local dealt = Descent.new(p, seed).companion
                assert(not dealt or dealt.house ~= house,
                    "seed " .. seed .. " dealt a companion the company already has")
            end
        end,
    },
    {
        -- GYEOM IS THE BODY THAT FILLS THE EXPEDITION, AND SHE IS NOT ROLLED FOR
        -- (Descent.SCRIPTED_COMPANION).
        --
        -- Everything else in this file is about a roll that can come up empty, which is the right shape
        -- for a company that already knows what a companion is. It is the wrong shape for the FIRST
        -- descent: the deck is drawn from counters the company has walked into, the seven shelves are
        -- behind a class level and behind that very descent (data/buildings/houses.lua), so on the run
        -- where meeting somebody matters most the deck is empty rather than unlucky and the rolled path
        -- deals nobody at all. Pinned across a spread of seeds because "every descent" is the claim.
        --
        -- WHO is scripted is pinned by name, and the name carries an argument a seed assertion cannot.
        -- The company walks out of Act 0 with three -- avatar, Rowan, Amana -- against PARTY_MAX of four,
        -- so this is the seat-filler; and what those three have no answer to is magic damage, not another
        -- sword at range. A change that quietly moved the script to the Hunter's Lodge would still pass
        -- every seed check below while handing the player a second body that answers what Rowan answers.
        name = "Gyeom stands on floor one of every descent until she joins",
        fn = function()
            local fresh = company() -- a new game: nothing done, nobody visited
            local scripted = Descent.SCRIPTED_COMPANION
            local opener = Errand.opener(scripted)
            assert(opener and Quest.defs[opener].rewardCharacter == "character_gyeom",
                scripted .. "'s posting does not hand over Gyeom, so scripting it recruits somebody else")
            assert(require("models.character").instantiate("character_gyeom").class == "mage",
                "the seat this fills is the magic one; a re-classed Gyeom means re-reading the choice")
            -- THE ARITHMETIC THE CHOICE RESTS ON, pinned so it fails here rather than in a playtest.
            -- Act 0 hands over three (the avatar, plus Rowan and Amana, both recruited in
            -- states/prologue.lua's buildBeats) and this is the fourth. Move PARTY_MAX and the scripted
            -- body stops being a seat-filler -- it becomes either a spare or one short of a legal party,
            -- and the whole "why the mage" reasoning above has to be re-argued against a different hole.
            assert(Descent.PARTY_MAX == 4,
                "Act 0's three plus the scripted body is a full expedition only while the cap is four")

            for _, seed in ipairs({ 1, 12345, 777, 4242, 99, 31337 }) do
                local dealt = Descent.new(fresh, seed).companion
                assert(dealt, "seed " .. seed .. " offered a new company nobody at all")
                assert(dealt.house == scripted and dealt.floor == 1, "seed " .. seed .. " put "
                    .. dealt.house .. " on floor " .. dealt.floor .. " instead of Gyeom on floor one")
                -- ...and she is actually SEATED there, which is the half the deal cannot promise on its
                -- own: openersAt is what the floor builder reads.
                local here = Descent.openersAt(Descent.new(fresh, seed), 1)
                assert(#here == 1 and here[1] == scripted, "floor one seats nobody")
            end

            -- A NIL PLAYER TAKES THE ROLL. It is a fixture with no roster to be missing her from, so
            -- there is nothing for the script to answer -- and a scripted meeting on every headless floor
            -- built without a company would hand a recruit to every spec that never asked for one. The
            -- roll can come up empty and the script cannot, so an empty seed is the proof it ran.
            local emptyForNobody = false
            for seed = 1, 200 do
                if not Descent.dealCompanion(seed, nil) then emptyForNobody = true break end
            end
            assert(emptyForNobody, "a nil player is being handed the scripted meeting rather than the roll")

            -- ...and the moment her posting is finished the script is spent and the roll takes over. This
            -- is what stops a descent spending its one offer on a body already in the party.
            local joined = company(scriptedJoined())
            for _, vendorId in ipairs(houses()) do Player.markVendorVisited(joined, vendorId) end
            for seed = 1, 200 do
                local dealt = Descent.new(joined, seed).companion
                assert(not (dealt and dealt.house == scripted),
                    "the scripted companion was offered again after she had joined")
            end
        end,
    },
    {
        -- A run CAN meet nobody, and that is the feature rather than a hole: if every descent produced a
        -- body the roll would be a rota with extra steps.
        name = "some descents offer nobody at all",
        fn = function()
            local visited = company(scriptedJoined())
            for _, vendorId in ipairs(houses()) do Player.markVendorVisited(visited, vendorId) end
            local empty, dealt = 0, 0
            for seed = 1, 400 do
                if Descent.new(visited, seed).companion then dealt = dealt + 1 else empty = empty + 1 end
            end
            assert(empty > 0, "every one of 400 seeds met somebody; the roll is not a roll")
            assert(dealt > 0, "no seed in 400 met anybody; the roll never fires")
        end,
    },
    {
        -- YOU MEET THE TRAINER FIRST. A companion stands behind their house's counter; the posting is
        -- the second half. A house whose door this company has never opened must post nobody, or the
        -- body is recruited by somebody who has never met them.
        name = "only a house whose counter has been visited posts its companion",
        fn = function()
            -- The scripted companion already in the company, or the scripted deal answers before the
            -- visit gate is ever consulted and this case would be measuring the wrong path
            -- (Descent.SCRIPTED_COMPANION).
            local stranger = company(scriptedJoined())
            local dealtToStranger = 0
            for seed = 1, 200 do
                if Descent.new(stranger, seed).companion then dealtToStranger = dealtToStranger + 1 end
            end
            assert(dealtToStranger == 0,
                "a company that has walked into no shop was still offered " .. dealtToStranger .. " bodies")

            -- One counter visited, and only that house can be dealt.
            local one = houses()[1]
            local met = company(scriptedJoined())
            Player.markVendorVisited(met, one)
            for seed = 1, 200 do
                local dealt = Descent.new(met, seed).companion
                if dealt then
                    assert(dealt.house == one,
                        "dealt " .. dealt.house .. " to a company that has only met " .. one)
                end
            end
        end,
    },
    {
        -- Nobody is offered twice. Once they are walking with you their posting is finished work, and a
        -- descent that spent its one deal on it would offer nothing at all.
        name = "a companion already recruited is never dealt again",
        fn = function()
            local one = houses()[1]
            local p = company(scriptedJoined({ [Errand.opener(one)] = true }))
            for _, vendorId in ipairs(houses()) do Player.markVendorVisited(p, vendorId) end
            for seed = 1, 200 do
                local dealt = Descent.new(p, seed).companion
                assert(not (dealt and dealt.house == one),
                    one .. " was dealt again after its companion had joined")
            end
        end,
    },
    {
        -- The floor is a function of the seed; WHO is standing on it is not, so the deal is stamped on
        -- the run and rides in the save. A resume that re-dealt would hand a different name to a company
        -- already standing in the chamber -- and re-entering a cleared floor would seat the NEXT body on
        -- the same ground, which is two companions from one descent's single offer.
        name = "the deal is stamped on the run and survives a save",
        fn = function()
            local p = company(scriptedJoined())
            for _, vendorId in ipairs(houses()) do Player.markVendorVisited(p, vendorId) end
            local a, b = Descent.new(p, 777), Descent.new(p, 777)
            assert((a.companion == nil) == (b.companion == nil), "the same seed dealt differently")
            if a.companion then
                assert(a.companion.house == b.companion.house and a.companion.floor == b.companion.floor,
                    "the same seed and the same company dealt a different meeting")
            end

            p.descentRun = Descent.new(p, 4242)
            local before = p.descentRun.companion
            local back = Save.restore(Save.decode("return " .. Save.encode(Save.snapshot(p), 0)))
            local after = back.descentRun and back.descentRun.companion
            if before then
                assert(after and after.house == before.house and after.floor == before.floor,
                    "the run came back offering somebody else")
            else
                assert(after == nil, "a run that offered nobody came back offering somebody")
            end
        end,
    },
    {
        -- THE BUG THIS PINS was live and invisible: agreeing to a posting set `errandAnswered` on the
        -- DOOR -- a fact about that cell, which stops the same question being asked twice -- and wrote
        -- nothing to the run. So a company that had said yes carried no record of it: no checklist row,
        -- nothing in the shop's list of outstanding asks, and nowhere at all that said what they had
        -- agreed to or which floor it was on.
        name = "an unaccepted posting is not on the worklist, and accepting is what puts it there",
        fn = function()
            local p = company()
            local ask = Errand.opener(houses()[1])

            assert(Errand.unaskedPosting(p, ask),
                "a posting the company has not agreed to is not work they are carrying")

            Errand.accept(p, ask, 1)
            assert(not Errand.unaskedPosting(p, ask), "saying yes is what makes it theirs")

            -- ...and it stops being outstanding once it is run, rather than sitting on the list forever.
            p.completedQuests[ask] = true
            assert(not Errand.unaskedPosting(p, ask), "a finished posting is not unasked either")
        end,
    },
    {
        -- An ordinary quest is not a posting and must never be filtered off the worklist by this rule:
        -- the gate exists for the seven asks a companion makes, and a rule that swept up anything else
        -- would hide real work from the checklist with nothing on screen to say why.
        name = "the worklist gate only ever hides a companion's own ask",
        fn = function()
            local p = company()
            assert(not Errand.unaskedPosting(p, "quest_no_such_thing"),
                "an id that is nobody's posting is not gated")
            assert(not Errand.unaskedPosting(p, nil), "and neither is nothing at all")
        end,
    },
}
