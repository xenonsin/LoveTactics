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
local Player = require("models.player")
local Quest = require("models.quest")     -- an errand IS a quest def; its intro is the house asking
local Vendor = require("models.vendor")

local VendorVisit = {}

-- THE HOUSE'S COMPANION JOINS AT ITS COUNTER, and this is the whole of how a company grows.
--
-- Each house names one body on its blueprint (`companion`, data/vendors/*.lua). You do not hire them
-- and nobody deals them: you meet them underground at that house's OPENER -- the errand lying unasked
-- on a floor, which is also the thing that opens the shop -- and then they are standing in the shop
-- when you first walk into it.
--
-- IT REPLACED A PULL. The Crossing dealt 1-of-45 for a token off the floors; what that produced was a
-- body with no reason to be yours, and a bond ladder nobody could climb (see the commit that removed
-- it). A companion earned by doing that house's work arrives already meaning something, and the seven
-- of them are the whole roster.
--
-- RECRUITED IN THE GREETING'S `before`, WHICH IS THE POINT rather than an implementation detail. The
-- scene is authored for the full roster through `when = { has = ... }` blocks, so the companion has to
-- BE in the company before their own lines can play -- and Player.recruit queues the
-- "[X has joined your Party]" banner onto the next scene to run (models/conversation.lua's noteJoin),
-- which is this one. Join, banner and first words all land in the same beat.
--
-- IT NO LONGER FIRES FOR ANYBODY, and the function is kept rather than deleted because the sequencing
-- it demonstrates is the contract the underground recruit has to honour.
--
-- Companions are met and recruited on a floor now (models/errand.lua's companion postings): you find
-- them at a dead end, they ask for one piece of work, and clearing it is what brings them into the
-- company. That is a beat the city cannot host -- the shop that used to host it was that house's own,
-- and the houses are classes now, so there is no counter to be standing behind.
--
-- What survives unchanged is the ORDER, which every recruit route must keep: Player.recruit queues the
-- "[X has joined your Party]" banner onto the next scene to run (models/conversation.lua's noteJoin),
-- and the scene is authored for the full roster through `when = { has = ... }` blocks -- so a companion
-- has to BE in the company before their own lines can play. Join, banner and first words land in one
-- beat, or they land wrong.
--
-- The one shop the city keeps declares no companion (data/vendors/market.lua), so this returns nil for
-- it by the check above rather than by a special case.
function VendorVisit.joinCompanion(player, vendorId)
    if not (player and vendorId) then return nil end
    local def = Vendor.get(vendorId)
    local companion = def and def.companion
    if not companion then return nil end
    return Player.recruit(player, companion)
end

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

    -- 1. First-visit greeting (data/conversations/<id>/conversation_<id>_vendor_intro.lua), and it is
    --    also where this house's companion joins -- see VendorVisit.joinCompanion.
    local introId = "conversation_" .. vendorId .. "_vendor_intro"
    if not Player.hasVisitedVendor(player, vendorId) and Conversation.defs[introId] then
        steps[#steps + 1] = { id = introId, before = function()
            Player.markVendorVisited(player, vendorId)
            VendorVisit.joinCompanion(player, vendorId)
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
