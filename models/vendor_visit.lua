-- WHAT A SHOP SAYS BEFORE IT SHOWS YOU THE SHELF.
--
-- Three things can be waiting behind a shop door, in this order, and each one records that it happened
-- so it never repeats across a save:
--
--   1. the greeting     a one-time first-visit scene, the shopkeeper meeting you (Player.hasVisitedVendor)
--   2. an announcement  one per newly unlocked discipline whose stock lands on this shelf
--
-- (3. was "the ask" -- the next errand this house wanted run, taken on over the counter. No house asks
-- for anything any more; the only asks in the game are the ones a companion makes on a floor.)
--
-- IT LIVED IN states/hub.lua UNTIL THE SHOPS MOVED. Every shelf was a pop-up over the city, so the city
-- was the only screen that had to know any of this. The seven houses and the General Store are on a
-- board of their own now (states/houses.lua, `district = "houses"`), and a second copy of ninety lines
-- of conversation sequencing is the kind of duplicate that stays right for about a week -- an errand
-- accepted on one screen and not the other is a shelf that disagrees with itself about what it asked
-- for. One copy, two callers.
--
-- Pure model: no love.graphics and no state switching. It plays conversations (a global overlay) and
-- hands control back through `onDone`, which is where the caller opens its own panel.

local Conversation = require("models.conversation")
local Class = require("models.class")
local Player = require("models.player")
local Quest = require("models.quest")     -- an errand IS a quest def; its intro is the house asking
local Vendor = require("models.vendor")

local VendorVisit = {}

-- (NO COMPANION JOINS AT A COUNTER, AND THE FUNCTION THAT DID ONE IS GONE.)
--
-- VendorVisit.joinCompanion stood here and it recruited the house's `companion` in the first-visit
-- greeting's `before`. Its own header said it no longer fired for anybody. It fired for everybody: the
-- call was live in the greeting step below, so walking into six shops handed over six companions for
-- the price of opening a door -- and the underground recruit it was supposedly deferring to had already
-- become the only route the design wanted (models/errand.lua). Two routes to the same body, one of them
-- free, is one route.
--
-- A companion is met on a floor, asks for one piece of work, and joins when it is cleared -- through the
-- posting's own `rewardCharacter`, which Quest.complete grants before the outro plays.
--
-- What that route inherits from this one is the ORDER, and it is a contract rather than a detail:
-- Player.recruit queues the "[X has joined your Party]" banner onto the next scene to run
-- (models/conversation.lua's noteJoin), and every scene is authored for the full roster through
-- `when = { has = ... }` blocks -- so a companion has to BE in the company before their own lines can
-- play. Join, banner and first words land in one beat, or they land wrong.

-- The scenes this shop owes the player right now, as a flat list of { id, before } steps. `before` runs
-- just ahead of its scene -- it is what records the flag, accepts the errand, or sets the token a line
-- of dialogue reads. An empty list means open straight to the shelf.
--
-- `deepest` is how far the company has got underground, which is what decides whether the next errand is
-- offered yet. Defaults to the run's own count off the player.
function VendorVisit.steps(player, vendorId, deepest)
    local steps = {}
    if not (player and vendorId) then return steps end
    deepest = deepest or (player.descentRun and player.descentRun.cleared) or 0

    -- 1. First-visit greeting (data/conversations/<id>/conversation_<id>_vendor_intro.lua). It hands
    --    over nobody: a shopkeeper meeting you is a greeting, and the body this house is tied to is met
    --    underground and recruited by the work she asks for (see the note above).
    local introId = "conversation_" .. vendorId .. "_vendor_intro"
    if not Player.hasVisitedVendor(player, vendorId) and Conversation.defs[introId] then
        steps[#steps + 1] = { id = introId, before = function()
            Player.markVendorVisited(player, vendorId)
        end }
    end

    -- 2. One announcement per newly unlocked discipline that stocks this shelf. The shop speaks; the
    -- {discipline} token names each one (set on the player for the scene's duration -- Locale.substitute).
    local vdef = Vendor.get(vendorId)
    local class = vdef and vdef.class
    local announceId = "conversation_" .. vendorId .. "_discipline_unlocked"
    if class and Conversation.defs[announceId] then
        for _, classId in ipairs(Class.pendingAnnouncements(player, class)) do
            local name = Class.defs[classId] and Class.defs[classId].name
            steps[#steps + 1] = { id = announceId, before = function()
                Player.markDisciplineAnnounced(player, classId)
                player.announcingDiscipline = name
            end }
        end
    end

    -- (3. THE HOUSE ASKED FOR SOMETHING, and no house asks any more.)
    --
    -- A shelf used to climb a rung at a time, each rung bought by running a small piece of work the
    -- house posted -- so when the company had been deep enough for the next one, the vendor asked for it
    -- on the way in and the errand was taken on there and then. The houses are classes now
    -- (docs/classes.md), and a class is climbed by a BODY playing its gear rather than by anybody
    -- running its errands, so there is nothing left for a shopkeeper to ask.
    --
    -- What the asking bought is worth keeping in view, because it has to be bought some other way: it
    -- was the one place the game said "there is a reason to go back down, and here is what it is". The
    -- companion recruits carry that now, and they say it underground where the work is.

    return steps
end

-- Play everything this shop owes, in order, then call `onDone`.
--
-- Each step records its flag BEFORE it plays and the batch saves once at the end, so a greeting or an
-- announcement never repeats across a save/load. The chain is built by recursion over the step list:
-- Conversation.play is callback-based and there is no other sequencer here.
--
-- `onDone` is called synchronously when there is nothing to say, which is the common case and must not
-- cost the player a frame of black screen on every shop they open.
function VendorVisit.play(player, vendorId, onDone, deepest)
    local steps = VendorVisit.steps(player, vendorId, deepest)
    if #steps == 0 then
        if onDone then onDone() end
        return
    end

    local function playFrom(i)
        local step = steps[i]
        if not step then
            player.announcingDiscipline = nil -- clear the token after the last scene
            Player.save()
            if onDone then onDone() end
            return
        end
        if step.before then step.before() end
        Conversation.play(step.id, function() playFrom(i + 1) end)
    end
    playFrom(1)
end

return VendorVisit
