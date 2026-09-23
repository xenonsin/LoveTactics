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
--
-- THERE WAS AN `opts.afterIntro(go)` SEAM HERE and it is gone with the beat it was cut for. It fired
-- once, after a house's `intro` scene and before its desk, and its one user was the wound window the
-- Cathedral's doorway owes a player who has never seen one (states/hub.lua's teachInjuries). That window
-- teaches the rule the ROOM is about, so it moved to the room's own door when the scene it was riding
-- moved to the far side of the press (see `introAfter` below) -- and a seam with no user is a seam
-- that goes stale unread. The host hangs the window off opening the room now, which is a moment the
-- host already owns and this module still knows nothing about.
--
-- `startAt` is nil on the way in -- the first visit of a session plays the scene whole -- and the desk's
-- own id on every return from a room.
function Counter.open(player, building, openPanel, onLeave, opts)
    assert(Counter.has(building), "no counter scene for " .. tostring(building and building.id))

    local introFlag = "intro_" .. tostring(building.id)
    player.flags = player.flags or {}

    local function introPending()
        return building.intro ~= nil
            and not player.flags[introFlag]
            and Conversation.defs[building.intro] ~= nil
    end

    -- Spend it: the flag, the companion, the save, the scene. The recruit fires BEFORE the scene
    -- wherever the scene is played from, because the banner folds onto the next one to run.
    local function playIntro(done)
        player.flags[introFlag] = true
        if building.grants then Player.recruit(player, building.grants) end
        Player.save()
        Conversation.play(building.intro, done)
    end

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

            openPanel(room, function()
                -- ...and a room named by `introAfter` plays the house's one-time scene as it shuts,
                -- once. Hung on the room CLOSING rather than on what was done inside it, because a
                -- panel is the host's and this module never learns what happened in one -- which is
                -- honest for the case it was built for: the coached morning holds the mending open
                -- until the bone is set (ui/panels/ward.lua's rail), so the close IS the deed.
                if building.introAfter == answer and introPending() then
                    return playIntro(function() desk(Counter.DESK) end)
                end
                desk(Counter.DESK)
            end)
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

    -- A HOUSE WITH ITS OWN ONE-TIME SCENE, played instead of the shopkeeper's greeting. `intro` is a
    -- scene the blueprint names and `grants` is the companion it hands over -- which is how the
    -- Cathedral introduces Xin, the one companion in the game met above ground.
    --
    -- KEYED ON ITS OWN FLAG, and the first version of this lived in states/hub.lua and was broken by
    -- being keyed on the city's announcement ledger instead (`player.seenDoors`, deleted with the
    -- plaza's coach bubbles). Those were two different questions: that ledger asked "has this card
    -- been ANNOUNCED", and the city seeded it wholesale on a first visit for every door already open
    -- -- so a room standing open from the start was seeded seen on the very first frame and its scene
    -- never fired for anybody. A scene played once is not the same fact as a card announced once, and
    -- conflating them silently ate a companion. It moved here with the rooms.
    --
    -- The recruit fires BEFORE the scene so the "[X has joined your Party]" banner folds onto the end of
    -- it, which is the route every other companion's join takes (models/conversation.lua's noteJoin).
    --
    -- IT PLAYS INSTEAD OF THE GREETING, not in front of it, on the one visit it fires. The Cathedral is
    -- why: its scene hands over Xin, its house has a shopkeeper's greeting of its own, and its desk
    -- speaks too -- so a player walking through that door on the first morning of the game sat through
    -- three scenes back to back, at the single most sensitive moment there is.
    --
    -- The greeting is DEFERRED rather than dropped: nothing marks the vendor visited here, so it plays
    -- on the next visit, which is also the visit where the player might have a reason to look at the
    -- shelf it is about. One scene per trip through the door.

    -- A SCENE THAT WAITS FOR A DEED INSTEAD OF A DOOR. `introAfter` names one of this house's own
    -- answers, and a blueprint that carries it is saying its intro belongs on the way OUT of that
    -- room rather than on the way in.
    --
    -- The Cathedral is why, and it is the difference between a healer who is announced and one who
    -- does something: her scene played in the doorway, so a player met Xin, was told a bone could be
    -- set, and then went and set it themselves off a menu. It plays on the press now -- she is the one
    -- who mends Rowan, and she asks to come off the back of having done it.
    --
    -- THE GREETING STAYS DEFERRED EITHER WAY. One scene per trip through the door is the rule this
    -- branch was written for, and moving the scene later does not buy the shopkeeper's preamble a slot
    -- -- least of all here, where that preamble is six lines about a shelf that is still shut. Nothing
    -- marks the vendor visited, so the greeting plays on the next visit exactly as it did before.
    if introPending() then
        if building.introAfter then return desk(Counter.DESK) end
        -- Straight to the desk afterwards, for the reason the paragraph above this one gives twice over:
        -- the house has just spoken at length, and its keeper's preamble on the back of that is the
        -- third scene this branch exists to avoid.
        return playIntro(function() desk(Counter.DESK) end)
    end
    greet()
end

return Counter
