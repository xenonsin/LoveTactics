-- A COUNTER: a shopkeeper, a desk, and every room behind that one door.
--
-- THE CITY USED TO BE SIXTEEN CARDS ACROSS TWO BOARDS. Nine on the plaza and seven more on a square
-- behind one of them, and over half of the sixteen were the same kind of thing -- a shelf you browse.
-- The plaza ran out of slots twice (models/building.lua's GRID), and the seven shopfronts had already
-- been moved off it once for exactly that reading.
--
-- SO THE ROOMS WERE FOLDED INTO THE HOUSES. Nine cards on one board: the Rift, the Armory, and the seven
-- houses -- and every other room the city had is a LINE on one of their desks. The Inn is what the
-- Cathedral offers besides its shelf; the bench is what the Bastion offers; the supper is the Lodge's.
-- Nothing was deleted but the plates.
--
-- WHAT A VISIT LOOKS LIKE, and this module owns all four beats:
--
--   1. the house says what it owes you   models/vendor_visit.lua -- the one-time greeting, any new
--                                        discipline. Unchanged, and still shared with nothing else now.
--   2. the counter scene plays           and ENDS on a desk: one node whose `choices` are the rooms,
--                                        each line appearing only if its room is open (models/offer.lua,
--                                        the `offer` predicate)
--   3. the room opens                    the `answer` on the committed choice names a panel
--   4. closing it comes back to the DESK  not to the greeting -- Conversation.play's `startAt`
--
-- ...AND 4 LOOPS TO 3, so a player can mend a bone, then read a find, then browse, then leave, without
-- the door closing between them. The loop ends when the desk reports an answer that is not a room --
-- the Exit line, or nothing at all when the scene was escaped out of.
--
-- ONE COPY, EIGHT CALLERS. Seven houses each running their own version of "play the scene, read the
-- answer, open the panel, come back" is the duplicate that stays right for about a week, and the shape
-- of that mistake is already on the record: this is the same argument that moved the greeting sequence
-- out of states/hub.lua into models/vendor_visit.lua when the shops got a second screen.
--
-- IT OPENS NO PANEL ITSELF. `openPanel` is handed in by whatever state owns the screen, because only
-- that state knows where its modal goes and what else it has to pass a panel (states/hub.lua's
-- launchPanel does the Armory's filters, the reveal hand-off and the trainer walk). This module decides
-- WHICH room; the host decides how a room is put on screen. That keeps it a pure model -- no
-- love.graphics, no state switching -- so it loads under the headless runner.

local Conversation = require("models.conversation")
local Offer = require("models.offer")
local Player = require("models.player")
local VendorVisit = require("models.vendor_visit")

local Counter = {}

-- The node a counter scene comes back to. Every counter scene must carry a node with this id, and that
-- node must never wear a `when` of its own: it is the one line in the file that always exists, and a
-- desk gated out of its own scene is a door that opens onto the greeting forever
-- (ui/dialogue.lua's startAt falls back to the top when a label will not resolve).
Counter.DESK = "desk"

-- The answer that means "walk out". Authored on the Exit line of every desk. Anything unrecognised means
-- the same thing -- an escaped scene reports nil -- so leaving is the safe default and a typo in a
-- blueprint shuts the door rather than opening the wrong room.
Counter.LEAVE = "leave"

-- The conversation context for a counter: the ordinary one, plus which rooms behind this door are open.
-- Rebuilt on every pass through the desk rather than captured once, because a room can OPEN while the
-- player is standing at the counter -- setting a bone at the Cathedral is the case it was built for, and
-- a desk that still offered it afterwards would be a line about a problem the player just solved.
--
-- IT ALSO CARRIES WHAT IS WAITING IN EACH ROOM (`news`), which is a different question from whether the
-- line is there at all: the Cathedral's mending stands on the desk forever once anybody has been carried
-- up broken, and it is worth walking into only on the trips where somebody is hurt. A marked line is how
-- a desk says which of its four rooms wants you today -- the same red dot the house's own plate wears
-- out on the plaza, asked of one room instead of all of them (models/offer.lua's Offer.news).
function Counter.context(player, building)
    local ctx = Conversation.context(player)
    ctx.offers = Offer.openSet(player, building)
    ctx.news = Offer.newsSet(player, building)
    return ctx
end

-- Is there a counter behind this door at all? A building with no `counter` scene is a plain panel door
-- (the Armory) or a whole screen (the Rift), and its host opens it the way it always did.
function Counter.has(building)
    return building ~= nil
        and building.counter ~= nil
        and Conversation.defs[building.counter] ~= nil
end

-- Open `building`'s counter for `player`.
--
--   openPanel(room, onClosed)  `room` is { panel, vendor } -- the host puts that panel on screen and
--                              calls `onClosed` when it shuts. The host owns the rect; this owns the
--                              sequence. `room.vendor` is the counter behind the room, which is not
--                              always the house's own: see models/offer.lua's note on folded rooms.
--   onLeave()                  optional, fired once when the player walks out.
--   opts.afterIntro(go)        optional, fired ONCE -- on the single visit the house's `intro` scene
--                              plays -- after that scene and before the desk. The host does whatever
--                              it wants over the city and calls `go()` to hand back; not passing it,
--                              or not calling back, is what would leave the player standing on a
--                              closed scene, so a host that takes the seam owes the call.
--
-- WHY THE SEAM EXISTS AT ALL, since this file spent its first draft with no hooks in it: the
-- Cathedral's intro is the scene Xin joins out of (`grants`), and what the player is holding the
-- moment it ends is a wound and no idea that a wound is a thing you go and answer. That is a FEATURE
-- lesson -- a tutorial window, not a bubble (ui/panels/tutorial_note.lua draws the line) -- and a
-- window is a panel, which this module deliberately knows nothing about. So the host is handed the
-- beat instead of this module learning what a modal is.
--
-- Keyed on the intro rather than on a flag of its own, which is the whole reason it is offered HERE
-- and not from the desk: `flags.intro_<id>` already fires exactly once, ever, and a second ledger for
-- "has the window been seen" would be a second thing that can disagree with the first.
--
-- `startAt` is nil on the way in -- the first visit of a session plays the scene whole -- and the desk's
-- own id on every return from a room.
function Counter.open(player, building, openPanel, onLeave, opts)
    assert(Counter.has(building), "no counter scene for " .. tostring(building and building.id))

    local function leave()
        Player.save()
        if onLeave then onLeave() end
    end

    -- One pass: play the scene (from the top, or back at the desk), then act on what was answered.
    local function desk(startAt)
        Conversation.play(building.counter, function(answer)
            if not answer or answer == Counter.LEAVE then return leave() end

            -- A room, if the answer names one that is open. Offer.roomFor returns nil for the Exit line,
            -- for an unknown answer, and for an answer whose gate has shut since the scene was resolved
            -- -- all three of which mean "do not open anything".
            local room = Offer.roomFor(player, building, answer)
            if not room then return leave() end

            openPanel(room, function() desk(Counter.DESK) end)
        end, Counter.context(player, building), { startAt = startAt })
    end

    -- The house speaks first: the greeting, and any discipline it has not announced yet. Unchanged, and
    -- still the first thing behind a shop door.
    --
    -- AND IF IT HAS NOTHING TO SAY, THE DESK IS THE FIRST THING YOU SEE. A counter scene opens on a line
    -- of the keeper's flavour and ends on the desk, and that line is a GREETING -- it is the room
    -- introducing itself. Played from the top on every visit it became a keypress between the player and
    -- the four words they came through the door for, forever, at seven doors. So the preamble rides the
    -- visit the house is already speaking on -- the one-time intro, a newly unlocked discipline -- and
    -- every other visit opens ON the desk (`startAt`), the same node a closing room comes back to.
    --
    -- `spoke` is VendorVisit's own answer to "did I play anything", not a second ledger derived from the
    -- flags it writes: it records them BEFORE each scene plays, so anything asking afterwards would be
    -- told no.
    local function greet()
        VendorVisit.play(player, building.vendor, function(spoke)
            if spoke then return desk(nil) end
            desk(Counter.DESK)
        end)
    end

    -- A ROOM WITH ITS OWN ONE-TIME SCENE, ahead of the shopkeeper's greeting. `intro` is a scene the
    -- blueprint names and `grants` is the companion it hands over as it opens -- which is how the
    -- Cathedral introduces Xin, the one companion in the game met above ground.
    --
    -- KEYED ON ITS OWN FLAG, and the first version of this lived in states/hub.lua and was BROKEN BY
    -- Building.seenDoor. Those are two different questions: seenDoor asks "has this card been
    -- ANNOUNCED", and the city seeds it wholesale on a first visit for every door already open -- so a
    -- room standing open from the start was seeded seen on the very first frame and its scene never
    -- fired for anybody. A scene played once is not the same fact as a card announced once, and
    -- conflating them silently ate a companion. It moved here with the rooms.
    --
    -- The recruit fires BEFORE the scene so the "[X has joined your Party]" banner folds onto the end of
    -- it, which is the route every other companion's join takes (models/conversation.lua's noteJoin).
    --
    -- IT PLAYS INSTEAD OF THE GREETING, not in front of it, on the one visit it fires. The Cathedral is
    -- why: its room's scene hands over Xin, its house has a shopkeeper's greeting of its own, and its
    -- desk speaks too -- so a player walking through that door on the first morning of the game sat
    -- through three scenes back to back, at the single most sensitive moment there is.
    --
    -- The greeting is DEFERRED rather than dropped: nothing marks the vendor visited here, so it plays
    -- on the next visit, which is also the visit where the player might have a reason to look at the
    -- shelf it is about. One scene per trip through the door.
    local introFlag = "intro_" .. tostring(building.id)
    player.flags = player.flags or {}
    if building.intro and not player.flags[introFlag] and Conversation.defs[building.intro] then
        player.flags[introFlag] = true
        if building.grants then Player.recruit(player, building.grants) end
        Player.save()
        local afterIntro = opts and opts.afterIntro
        -- Straight to the desk afterwards, for the reason the paragraph above this one gives twice over:
        -- the house has just spoken at length, and its keeper's preamble on the back of that is the
        -- third scene this branch exists to avoid.
        Conversation.play(building.intro, function()
            if afterIntro then return afterIntro(function() desk(Counter.DESK) end) end
            desk(Counter.DESK)
        end)
        return
    end
    greet()
end

return Counter
