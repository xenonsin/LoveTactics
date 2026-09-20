-- THE FIRST WOUND IS TAUGHT ON THE MAP; EVERY ONE AFTER IT IS NOT, AND A WIPE IS NOT EITHER.
--
-- A wound (models/wound.lua) leaves a mark the player has never seen before -- the dark cap on that
-- body's health bar in the overworld party strip -- and from then on the rest of the expedition is
-- being routed by a company that is short of that much. The toast says WHO; it does not say what the
-- mark is. So the very first time anybody is carried out of a fight, states/game.lua pins a coach
-- bubble to that member's row in the strip (game:inflictWounds -> game.drawCoach's "wound" branch).
--
-- A WIPE SKIPS IT, and by construction rather than by a flag: every wipe path wounds and then leaves
-- the map inside the same function, so a bubble pinned to an overworld that is already gone draws
-- nothing. There is nothing left for it to point at either -- a wiped company is standing in a town,
-- and reaching a town sets every bone (models/wound.lua's Wound.clear), so the mark the bubble teaches
-- is not on any bar to be taught. The lesson waits for the first body carried out of a fight the
-- company survives, which is the fight where it means something.
--
-- AND THE SECOND HALF OF THE SAME LESSON IS TAUGHT IN TOWN, on the morning the city grows the room
-- that answers a wound. The map's bubble says what the mark on the bar IS; it cannot say what to do
-- about it, because down there the answer is a camp stop and not a door. The city's beat is where the
-- rule lands -- a window at the end of the Cathedral's first-visit scene, the one Xin joins out of
-- (states/hub.lua's teachWounds) -- and then a bubble on the Inn's own rows (ui/panels/ward.lua).
--
-- WHAT HOLDS THE TWO SURFACES TOGETHER is one predicate, Wound.unattended: the city's coaching stage
-- is spent when it empties and the panel rings the rows of whoever is first in it, so "seen to" cannot
-- mean two things on two screens. The cases at the bottom pin that, and the wiring around it.
--
-- None of that is reachable from a headless spec -- drawCoach is a love.graphics path hanging off a
-- state that mints fonts at require-time -- so what is pinned here is the three things a rename or a
-- layout change could break silently, each in the place it CAN be checked: the anchor the bubble hangs
-- on, the line it draws, and the gate that arms it once.

local PartyStatus = require("ui.party_status")
local Locale = require("models.locale")
local Conversation = require("models.conversation")
local Wound = require("models.wound")

local CONV = "conversation_tutorial_wound"
-- The city's bubbles, which is where the Inn's own coaching lines live (the plaza and the
-- room are one bag: both point at a control, and both need {select}).
local CITY_BAG = "conversation_tutorial_city"

local function roster(...)
    local out = {}
    for _, id in ipairs({ ... }) do out[#out + 1] = { id = id, name = id, stats = {} } end
    return { roster = out }
end

-- The Inn panel bakes its faces in `new`, and love.graphics.newFont throws with no window -- the same
-- stub tests/advancement_spec.lua and tests/shop_buy_spec.lua use. Nothing here draws; the rows only
-- have to be LAID OUT, which is arithmetic over the sizes these report.
local function stubFonts(fn)
    local gfx = love.graphics
    local real = gfx.newFont
    gfx.newFont = function()
        return {
            getHeight = function() return 18 end,
            getWidth = function(_, str) return #tostring(str or "") * 8 end,
            getWrap = function(_, text, _) return text, { text } end,
        }
    end
    local ok, err = pcall(fn)
    gfx.newFont = real
    if not ok then error(err, 0) end
end

local function nodeById(def, wanted)
    for _, node in ipairs(def.script or {}) do
        if node.id == wanted then return node end
    end
    return nil
end

return {
    {
        -- THE ANCHOR. The bubble names a BODY, so it hangs off that body's row rather than off the
        -- strip's corner -- which means the strip has to be able to say where a row is, at the origin
        -- the caller drew it at. Stated against PartyStatus.stripHeight rather than against the row
        -- pitch, so a strip laid out differently still passes as long as its rows and its height agree.
        name = "the party strip can point at one member's row, at the origin it was drawn at",
        fn = function()
            local player = roster("character_rowan", "character_kaen", "character_ren")
            local first = PartyStatus.rowRect(player, "character_rowan", 16, 60)
            local second = PartyStatus.rowRect(player, "character_kaen", 16, 60)
            local third = PartyStatus.rowRect(player, "character_ren", 16, 60)
            assert(first and second and third, "every marching member has a row")

            assert(first.x == 16 and first.y == 60, "the first row opens at the origin it was given")
            assert(first.w > 0 and first.h > 0, "a row is a rect the bubble can point at")
            local pitch = second.y - first.y
            assert(pitch > 0, "rows stack downward in roster order")
            assert(third.y - second.y == pitch, "and stack evenly")

            local height = PartyStatus.stripHeight(#player.roster)
            assert(third.y + third.h <= 60 + height,
                "the last row sits inside the height the strip reserves for it")

            -- Somebody who is not in the company has no row, and the caller draws nothing rather than
            -- pointing at whatever happened to be first.
            assert(PartyStatus.rowRect(player, "character_xin", 16, 60) == nil,
                "a body that is not marching has no row")
            assert(PartyStatus.rowRect(player, nil, 16, 60) == nil, "and neither has nobody")
        end,
    },
    {
        -- THE LINE. drawCoach resolves it by node id and draws nothing if the lookup misses, so a
        -- renamed id is a lesson that silently stops happening. Pinned from both ends: the node exists
        -- and resolves through Locale, and the state still asks for it by that name.
        name = "the first-wound coach line exists, and the overworld still asks for it by id",
        fn = function()
            local def = Conversation.defs[CONV]
            assert(def, CONV .. " is missing -- the first wound has nothing to say")
            local node = nodeById(def, "wound_hint")
            assert(node, CONV .. " no longer carries a `wound_hint` node")
            local text = Locale.text(CONV, node)
            assert(type(text) == "string" and #text > 0, "the hint resolves to real text")

            -- IT TEACHES THE MARK, NOT A ROOM. It used to be careful not to name the Inn, which could
            -- not be reached from the map; there is no Inn now and no building anywhere that sets a
            -- bone (models/wound.lua), so a line pointing at one would be sending the player to a door
            -- that does not exist. The rule is unchanged and the reason got stronger.
            assert(not text:lower():find("inn", 1, true),
                "the map's line must not send the player to a door they cannot walk to")
            -- ...and it must say what a wound actually is now, which is a thing with an END: held until
            -- the company is above ground, or until a camp is spent binding it. A line that still reads
            -- "nothing will fill it again" is describing the permanent ledger this design replaced.
            assert(text:lower():find("above ground", 1, true) or text:lower():find("bind", 1, true),
                "the line no longer tells the player how a wound ends")

            local src = assert(love.filesystem.read("states/game.lua"), "should be able to read the state")
            assert(src:find('hintNode("' .. CONV .. '", "wound_hint")', 1, true),
                "states/game.lua no longer draws the first-wound hint by that id")
        end,
    },
    {
        -- THE GATE. One lesson, ever: armed off Wound.everWounded read BEFORE the ledger moves, since
        -- Wound.inflict is what writes that one-way mark. Read against the source because the arming
        -- lives in a state method that cannot be loaded headless.
        name = "the wound coach is armed once, off the mark that is only unset the first time",
        fn = function()
            local src = assert(love.filesystem.read("states/game.lua"), "should be able to read the state")
            local from = src:find("function game:inflictWounds", 1, true)
            assert(from, "nothing inflicts wounds on the map any more -- retarget this case")
            local to = src:find("\nfunction ", from + 1)
            local body = src:sub(from, to or #src)

            assert(body:find('game.coach = "wound"', 1, true),
                "the first wound no longer arms the overworld lesson")
            local mark = body:find("Wound.everWounded", 1, true)
            assert(mark, "the lesson is no longer gated on the ever-wounded mark -- it would fire every fight")
            assert(mark < body:find('game.coach = "wound"', 1, true),
                "the mark must be read before Wound.inflict writes it, or the answer is never 'never'")
        end,
    },
    {
        -- THE PREDICATE THE CITY'S LESSON IS SPENT ON. "Still owed a mending" is not "wounded": resting
        -- drops no count on purpose (the stay is served by descending, Wound.tickRest), so a body laid
        -- up is still carrying the wound and is emphatically NOT still a thing to do something about.
        -- Reading Wound.wounded for the deed would hold the plaza on a player who had already answered
        -- it the free way -- which is the way the room is built around.
        name = "a body is owed a mending until it is treated OR laid up, and the two agree",
        fn = function()
            local player = roster("character_rowan", "character_kaen")
            player.wounds = { character_rowan = 1 }
            Wound.stamp(player)

            local owed = Wound.unattended(player)
            assert(#owed == 1 and owed[1].char.id == "character_rowan",
                "one hurt body, and it is the one carrying the wound")

            -- REST answers it without clearing it, which is the case the plain wounded list gets wrong.
            assert(Wound.rest(player, "character_rowan") > 0, "resting is free and always available")
            assert(#Wound.wounded(player) == 1, "the body is still carrying the wound while it lies up")
            assert(#Wound.unattended(player) == 0, "...but nothing is owed about it any more")

            -- ...and a SECOND wound taken on top of a stay is owed again: there is something left to do.
            player.wounds.character_rowan = 2
            Wound.stamp(player)
            assert(#Wound.unattended(player) == 0,
                "a body already in bed is not owed a second decision until it gets up")

            -- TREAT answers it the other way, from an untouched body.
            local paid = roster("character_rowan")
            paid.wounds, paid.gold = { character_rowan = 1 }, Wound.TREAT_COST
            Wound.stamp(paid)
            assert(#Wound.unattended(paid) == 1, "the bone is unset to start with")
            assert(Wound.treat(paid, "character_rowan"), "the purse covers it")
            assert(#Wound.unattended(paid) == 0, "and a set bone is owed nothing either")

            -- Nobody hurt at all is the backstop the city's stage clears on (states/hub.lua's
            -- introAdvance), so it must answer empty rather than nil.
            assert(#Wound.unattended(roster("character_rowan")) == 0, "an unhurt company owes nothing")
            assert(#Wound.unattended(nil) == 0, "and neither does no company at all")
        end,
    },
    {
        -- THE CITY'S STAGE IS SPENT BY THE DEED. It was spent by the DOOR for a pass, and what that
        -- bought was a player who walked into the Cathedral, met Xin, said "nothing today" at the desk
        -- and walked back out into a city that thought the lesson had landed -- still carrying the
        -- wound, with the one room that answers it now just another card among nine. Read against the
        -- source because the stage table is a local in a state that cannot be loaded headless.
        name = "the first morning holds the plaza on the mending until somebody is seen to",
        fn = function()
            local src = assert(love.filesystem.read("states/hub.lua"), "should be able to read the state")

            local from = src:find("local INTRO_STAGES", 1, true)
            assert(from, "the first-visit stages are gone -- retarget this case")
            local stages = src:sub(from, src:find("\nlocal function introStage", from, true) or #src)
            assert(stages:find("mend = true", 1, true),
                "the Ward stage no longer names a deed, so it is spent by opening the door again")

            -- ...and the deed is the shared predicate, not a second opinion about what mending means.
            assert(src:find("Wound.unattended", 1, true),
                "states/hub.lua no longer reads the predicate the Inn's own rows are rung from")

            -- The window rides the intro scene's own once-ever flag rather than a ledger of its own,
            -- which is the whole reason models/counter.lua grew the seam (its afterIntro).
            assert(src:find("afterIntro", 1, true), "the hub no longer takes the beat after a first visit")
            local counter = assert(love.filesystem.read("models/counter.lua"), "should read the counter")
            assert(counter:find("opts.afterIntro", 1, true) or counter:find("opts and opts.afterIntro", 1, true),
                "models/counter.lua no longer offers the beat between a first-visit scene and its desk")
        end,
    },
    {
        -- THE RING GOES ROUND THE PAID ROW, and that is the half a source grep cannot see. The window
        -- one beat earlier taught both ways out and ranked neither; the bubble ranks them, because on
        -- THIS morning resting benches Rowan for the descent the city is about to ask four bodies for.
        -- The rect is built from the menu's own laid-out rows, so a layout change moves the bubble with
        -- them rather than leaving it pointing at old coordinates.
        name = "the Inn rings the instant mend, puts the cursor on it, and only while it is coached",
        fn = function() stubFonts(function()
            local Ward = require("ui.panels.ward")
            local player = roster("character_rowan", "character_kaen")
            player.gold = Wound.TREAT_COST
            player.wounds = { character_rowan = 1 }
            Wound.stamp(player)

            local panel = Ward.new({ player = player, coach = true, onClose = function() end })
            panel:update(0)  -- the rows are laid out on the tick, not in the constructor

            local rows = 0
            for _, item in ipairs(panel.items) do
                assert(item.charId and item.kind, "every row names the body and the way out it is")
                if item.charId == "character_rowan" then rows = rows + 1 end
            end
            assert(rows == 2, "a purse that covers the treatment offers both ways out, got " .. rows)

            local i, _, kind = panel:coachIndex()
            assert(kind == "treat",
                "the coach names the row that sets the bone today, got " .. tostring(kind))
            assert(panel.items[i].charId == "character_rowan", "...on the body that is actually hurt")

            -- THE CURSOR IS ON THE ROW THE BUBBLE NAMES. The bubble wears a key cap, and the cap is a
            -- promise about what that key does -- the same rule states/hub.lua's focusCoachedCard keeps
            -- on the plaza. A ring on one row and a highlight on another is two controls each claiming
            -- to be the live one.
            assert(panel.menu.selected == i, "the selection sits on the coached row")

            local rect, who, drawnKind = panel:coachRect()
            assert(rect and drawnKind == "treat", "the coached visit has something to ring")
            assert(who == "character_rowan", "and it names the body, for the bubble's own token")
            local item = panel.items[i]
            assert(rect.x == item.x and rect.y == item.y and rect.w == item.w and rect.h == item.h,
                "the ring is that row and not the block")
            for j, other in ipairs(panel.items) do
                if j ~= i then assert(other.y ~= rect.y, "no other row shares the ring") end
            end

            -- An ordinary visit is not coached at all: no flag, no bubble, whoever is hurt.
            local plain = Ward.new({ player = player, onClose = function() end })
            plain:update(0)
            assert(plain:coachRect() == nil, "an uncoached Inn draws no bubble")

            -- ...and the coached one goes quiet the instant the wound is answered, on the same
            -- predicate the city spends its stage on -- so the ring and the plaza cannot disagree.
            -- REST answers it, though rest is not the row that was pointed at: the deed the city spends
            -- its stage on is wider than the instruction (states/hub.lua's mendingDone), which is what
            -- keeps this a recommendation rather than a rail.
            assert(Wound.rest(player, "character_rowan") > 0, "rest is the free way out")
            panel:rebuild()
            panel:update(0)
            assert(panel:coachRect() == nil, "a body that has been seen to is no longer rung")
        end) end,
    },
    {
        -- A PURSE THAT CANNOT COVER THE BONE. Unreachable in the campaign as it stands -- the company
        -- walks out of Act 0 with 250g against a 40g bone -- and it is authored and pinned anyway,
        -- because the city HOLDS THE PLAZA until somebody is seen to. A coached room whose bubble
        -- pointed at nothing would not be merely unhelpful the day that figure moves; it would leave
        -- the first morning unfinishable.
        name = "a purse short of the bone is coached to the free row, in its own words",
        fn = function() stubFonts(function()
            local Ward = require("ui.panels.ward")
            local player = roster("character_rowan")
            player.gold = Wound.TREAT_COST - 1
            player.wounds = { character_rowan = 1 }
            Wound.stamp(player)

            local panel = Ward.new({ player = player, coach = true, onClose = function() end })
            panel:update(0)
            assert(#panel.items == 1 and panel.items[1].kind == "rest",
                "a row that cannot be pressed is not drawn as a row")

            local i, _, kind = panel:coachIndex()
            assert(kind == "rest", "the coach falls back to the row that is actually there")
            assert(panel.menu.selected == i, "and the cursor follows it")

            -- ...and it says so in a line of its own rather than describing a row it is not pointing at.
            local text = Locale.coach(CITY_BAG, "mend_rest", { who = "Rowan" })
            assert(text and text:find("Rowan", 1, true),
                "the free row's own line exists and names the body")
            assert(not text:find("{", 1, true), "...and leaves no token unfilled")
        end) end,
    },
}
