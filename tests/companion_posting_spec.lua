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

-- THE QUEST BLUEPRINTS ARE GONE, AND SO IS WHAT THEY WERE COVERING. data/quests was deleted
-- with the seven house postings (92ff549d), which took companion recruitment, the market's openers,
-- Saber's debut and every `slot_01` with it. The cases below had no data left to run against and
-- were removed on 2026-09-23 rather than left red. Each one is listed so the hole is findable:
--
--   * Gyeom stands on floor one of every descent until she joins
--   * a companion already recruited is never dealt again
--   * a companion who joined without finishing her posting still reads as joined
--   * a descent offers one companion at most, on one floor
--   * a posting hands over the companion it was met with
--   * accepting an ask marks it on the floor it was met on, and says so until it is done
--   * an accepted ask survives a save, floor and all
--   * an ask is outstanding until it is run, and finishing it is what joins them
--   * an unaccepted posting is not on the worklist, and accepting is what puts it there
--   * every class with a companion posts an ask that exists and can be fought
--   * only a house whose counter has been visited posts its companion
--   * some descents offer nobody at all
--   * the deal is stamped on the run and survives a save
--   * the deck is the postings that recruit, not the houses that name a body
--
-- Nothing above is a rule that was decided against; it is coverage that lost its subject. When the
-- replacement for the postings lands, these are the cases it owes back.

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
-- another (it was Saber's, it is Xin's) leaves every fixture below correct.
local function scriptedJoined(done)
    done = done or {}
    done[Errand.opener(Descent.SCRIPTED_COMPANION)] = true
    return done
end

return {
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
