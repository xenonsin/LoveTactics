-- WHAT A SHOP SAYS BEFORE IT SHOWS YOU THE SHELF.
--
-- Three things can be waiting behind a shop door, in this order, and each one records that it happened
-- so it never repeats across a save:
--
--   1. the greeting     a one-time first-visit scene, the shopkeeper meeting you (Player.hasVisitedVendor)
--   2. an announcement  one per newly unlocked discipline whose stock lands on this shelf
--   3. the ask          the next errand this house wants run, taken on there and then (models/errand.lua)
--
-- IT LIVED IN states/hub.lua UNTIL THE SHOPS MOVED. Every shelf was a pop-up over the city, so the city
-- was the only screen that had to know any of this. The seven houses and the General Store are on a
-- board of their own now (states/markets.lua, `district = "market"`), and a second copy of ninety lines
-- of conversation sequencing is the kind of duplicate that stays right for about a week -- an errand
-- accepted on one screen and not the other is a shelf that disagrees with itself about what it asked
-- for. One copy, two callers.
--
-- Pure model: no love.graphics and no state switching. It plays conversations (a global overlay) and
-- hands control back through `onDone`, which is where the caller opens its own panel.

local Conversation = require("models.conversation")
local Discipline = require("models.discipline")
local Errand = require("models.errand")
local Player = require("models.player")
local Quest = require("models.quest")     -- an errand IS a quest def; its intro is the house asking
local Vendor = require("models.vendor")

local VendorVisit = {}

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

    -- 1. First-visit greeting (data/conversations/<id>/conversation_<id>_vendor_intro.lua).
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
        for _, disciplineId in ipairs(Discipline.pendingAnnouncements(player, class)) do
            local name = Discipline.defs[disciplineId] and Discipline.defs[disciplineId].name
            steps[#steps + 1] = { id = announceId, before = function()
                Player.markDisciplineAnnounced(player, disciplineId)
                player.announcingDiscipline = name
            end }
        end
    end

    -- 3. THE HOUSE ASKS FOR SOMETHING. A shelf climbs a rung at a time and each rung is bought by doing
    -- a small piece of work for the house (models/errand.lua) -- so when the company has been deep
    -- enough for the next one, the vendor asks for it before the shelf opens, and the errand is taken on
    -- there and then.
    --
    -- ACCEPTED BY BEING ASKED, with no yes-or-no. A refusal would be a door onto the same conversation
    -- tomorrow and a shelf that stays shut for no reason the player chose -- and there is nothing to
    -- weigh, because an errand costs nothing to hold. Where it is, and whether to go, is the decision;
    -- it is on the floor and in the shop's Errands tab either way.
    --
    -- The FIRST errand of a line is never reached here, and that is the door model rather than an
    -- exception: it is the opener, it is found on a floor, and running it is what put this shop on the
    -- board at all. By the time anybody stands in this doorway `Errand.next` is already past it.
    local offered = Errand.offered(player, vendorId, deepest)
    if offered then
        local def = Quest.defs[offered]
        local floor = Errand.floorFor(player, vendorId)
        local function take() Errand.accept(player, offered, floor) end
        if def and def.intro and Conversation.defs[def.intro] then
            steps[#steps + 1] = { id = def.intro, before = take }
        else
            take()
        end
    end

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
