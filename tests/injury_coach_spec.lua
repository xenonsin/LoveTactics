-- THE FIRST INJURY IS TAUGHT ON THE MAP; EVERY ONE AFTER IT IS NOT, AND A WIPE IS NOT EITHER.
--
-- An injury (models/injury.lua) leaves a mark the player has never seen before -- the dark cap on that
-- body's health bar in the overworld party strip -- and from then on the rest of the expedition is
-- being routed by a company that is short of that much. The toast says WHO; it does not say what the
-- mark is. So the very first time anybody is carried out of a fight, states/game.lua pins a coach
-- bubble to that member's row in the strip (game:inflictInjuries -> game.drawCoach's "injury" branch).
--
-- A WIPE SKIPS IT, and by construction rather than by a flag: every wipe path injures and then leaves
-- the map inside the same function, so a bubble pinned to an overworld that is already gone draws
-- nothing. There is nothing left for it to point at either -- a wiped company is standing in a town,
-- and reaching a town sets every bone (models/injury.lua's Injury.clear), so the mark the bubble teaches
-- is not on any bar to be taught. The lesson waits for the first body carried out of a fight the
-- company survives, which is the fight where it means something.
--
-- AND THE SECOND HALF OF THE SAME LESSON IS TAUGHT IN TOWN, on the morning the city grows the room
-- that answers an injury. The map's bubble says what the mark on the bar IS; it cannot say what to do
-- about it, because down there the answer is a camp stop and not a door. The city's beat is where the
-- rule lands -- a window in the doorway of the mending itself (states/hub.lua's teachInjuries) -- and
-- then a bubble on the one row the room offers that morning (ui/panels/ward.lua's rail). What the
-- press hands to is the scene the healer sets the bone in and asks to come out of.
--
-- WHAT HOLDS THE TWO SURFACES TOGETHER is one predicate, Injury.unattended: the city's coaching stage
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
local Injury = require("models.injury")

local CONV = "conversation_tutorial_injury"
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
        name = "the first-injury coach line exists, and the overworld still asks for it by id",
        fn = function()
            local def = Conversation.defs[CONV]
            assert(def, CONV .. " is missing -- the first injury has nothing to say")
            local node = nodeById(def, "injury_hint")
            assert(node, CONV .. " no longer carries a `injury_hint` node")
            local text = Locale.text(CONV, node)
            assert(type(text) == "string" and #text > 0, "the hint resolves to real text")

            -- IT TEACHES THE MARK, NOT A ROOM. It used to be careful not to name the Inn, which could
            -- not be reached from the map; there is no Inn now and no building anywhere that sets a
            -- bone (models/injury.lua), so a line pointing at one would be sending the player to a door
            -- that does not exist. The rule is unchanged and the reason got stronger.
            assert(not text:lower():find("inn", 1, true),
                "the map's line must not send the player to a door they cannot walk to")
            -- ...and it must say what an injury actually is now, which is a thing with an END -- and
            -- the end is NOT the walk home. The line read "stays held back until we are above ground
            -- again" for months after Injury.clear was deleted, which taught the player they could walk
            -- it off; so the two things it may name are the camp's bind and the Ward, and "above
            -- ground" is now a FAILURE rather than a pass.
            assert(not text:lower():find("above ground", 1, true),
                "the line promises the surface sets bones, which it has not done since the Ward was built")
            assert(text:lower():find("bind", 1, true) or text:lower():find("ward", 1, true),
                "the line no longer tells the player how an injury ends")

            local src = assert(love.filesystem.read("states/game.lua"), "should be able to read the state")
            -- ONE BRANCH, TWO LINES: the first-injury hint and the first-BADGE hint are pinned to the
            -- same row and spent by the same step, so the id is chosen in an expression rather than
            -- typed as a literal. Both ids are asserted, because a branch that can only ever reach one
            -- of them is the failure this case is here to catch.
            assert(src:find('hintNode("' .. CONV .. '"', 1, true),
                "states/game.lua no longer draws the injury hints from that conversation")
            assert(src:find('"injury_hint"', 1, true), "the first-injury hint id is gone from the state")
            assert(src:find('"badge_hint"', 1, true), "the first-badge hint id is gone from the state")
        end,
    },
    {
        -- THE GATE. One lesson, ever: armed off Injury.everInjured read BEFORE the ledger moves, since
        -- Injury.inflict is what writes that one-way mark. Read against the source because the arming
        -- lives in a state method that cannot be loaded headless.
        name = "the injury coach is armed once, off the mark that is only unset the first time",
        fn = function()
            local src = assert(love.filesystem.read("states/game.lua"), "should be able to read the state")
            local from = src:find("function game:inflictInjuries", 1, true)
            assert(from, "nothing inflicts injuries on the map any more -- retarget this case")
            local to = src:find("\nfunction ", from + 1)
            local body = src:sub(from, to or #src)

            assert(body:find('game.coach = "injury"', 1, true),
                "the first injury no longer arms the overworld lesson")
            local mark = body:find("Injury.everInjured", 1, true)
            assert(mark, "the lesson is no longer gated on the ever-injured mark -- it would fire every fight")
            assert(mark < body:find('game.coach = "injury"', 1, true),
                "the mark must be read before Injury.inflict writes it, or the answer is never 'never'")
        end,
    },
    {
        -- THE PREDICATE THE CITY'S LESSON IS SPENT ON. "Still owed a mending" is not "injured": resting
        -- drops no count on purpose (the stay is served by descending, Injury.tickRest), so a body laid
        -- up is still carrying the injury and is emphatically NOT still a thing to do something about.
        -- Reading Injury.injured for the deed would hold the plaza on a player who had already answered
        -- it the free way -- which is the way the room is built around.
        name = "a body is owed a mending until it is treated OR laid up, and the two agree",
        fn = function()
            local player = roster("character_rowan", "character_kaen")
            player.injuries = { character_rowan = { "injury_blood_loss" } }
            Injury.stamp(player)

            local owed = Injury.unattended(player)
            assert(#owed == 1 and owed[1].char.id == "character_rowan",
                "one hurt body, and it is the one carrying the injury")

            -- REST answers it without clearing it, which is the case the plain injured list gets wrong.
            assert(Injury.rest(player, "character_rowan") > 0, "resting is free and always available")
            assert(#Injury.injured(player) == 1, "the body is still carrying the injury while it lies up")
            assert(#Injury.unattended(player) == 0, "...but nothing is owed about it any more")

            -- ...and a SECOND injury taken on top of a stay is owed again: there is something left to do.
            player.injuries.character_rowan = { "injury_blood_loss", "injury_blood_loss" }
            Injury.stamp(player)
            assert(#Injury.unattended(player) == 0,
                "a body already in bed is not owed a second decision until it gets up")

            -- TREAT answers it the other way, from an untouched body.
            local paid = roster("character_rowan")
            paid.injuries, paid.gold = { character_rowan = { "injury_blood_loss" } }, Injury.TREAT_COST
            Injury.stamp(paid)
            assert(#Injury.unattended(paid) == 1, "the bone is unset to start with")
            assert(Injury.treat(paid, "character_rowan"), "the purse covers it")
            assert(#Injury.unattended(paid) == 0, "and a set bone is owed nothing either")

            -- Nobody hurt at all is the backstop the city's stage clears on (states/hub.lua's
            -- introAdvance), so it must answer empty rather than nil.
            assert(#Injury.unattended(roster("character_rowan")) == 0, "an unhurt company owes nothing")
            assert(#Injury.unattended(nil) == 0, "and neither does no company at all")
        end,
    },
    {
        -- THE FIRST MORNING'S FLAG IS SPENT BY THE DEED. It was spent by the DOOR for a pass, and what
        -- that bought was a player who walked into the Cathedral, met Xin, said "nothing today" at the
        -- desk and walked back out into a city that thought the lesson had landed -- still carrying the
        -- injury, with the one room that answers it now just another card among nine. Read against the
        -- source because the flag is read by locals in a state that cannot be loaded headless.
        --
        -- IT NO LONGER HOLDS THE PLAZA, and nothing does: the door refusal that came with the city's
        -- coach is cut (states/hub.lua's header, and tests/hub_doors_spec.lua pins openPanel). One
        -- bubble came back out there and it turns nothing down -- see the case below. `hubIntro`
        -- survives as the ledger BOTH surfaces read, and the rail that holds the player is the ROOM's
        -- (ui/panels/ward.lua), which is the half of this that was ever load-bearing.
        name = "the first morning's flag is spent by the mending, not by the door",
        fn = function()
            local src = assert(love.filesystem.read("states/hub.lua"), "should be able to read the state")

            assert(src:find('hub.player.hubIntro == "ward"', 1, true),
                "the first morning's flag is gone -- retarget this case")
            -- SPENT BY THE DEED: introAdvance clears it on the predicate, not on a door being opened.
            local from = assert(src:find("local function introAdvance", 1, true),
                "introAdvance is still what spends the flag")
            local body = src:sub(from, src:find("\nfunction hub.", from, true) or #src)
            assert(body:find("mendingDone()", 1, true),
                "the flag no longer clears on the mending, so it is spent by opening the door again")

            -- ...and the deed is the shared predicate, not a second opinion about what mending means.
            assert(src:find("Injury.unattended", 1, true),
                "states/hub.lua no longer reads the predicate the Ward's own rows are rung from")

            -- THE WINDOW IS HUNG ON THE ROOM, not on a scene. It rode the Cathedral's first-visit
            -- scene until that scene moved to the far side of the mending press (the blueprint's
            -- `introAfter`), where a window teaching the decision would arrive after it was taken.
            -- It still keeps no ledger: the stage it is fired on is spent by the deed.
            assert(src:find("teachInjuries(show)", 1, true),
                "the hub no longer teaches the injury in the doorway of the room that answers it")
            assert(src:find("coachingMend()", 1, true), "...and it is no longer gated on the coached morning")
            assert(not src:find("afterIntro", 1, true),
                "the hub still reaches for a seam that is gone -- the window hangs off the room now")
        end,
    },
    {
        -- THE COACHED MORNING IS A RAIL, and every half of it is here. The window one beat earlier
        -- taught both ways out and ranked neither; this room ranks them by offering ONE -- because on
        -- THIS morning resting benches Rowan for the descent the city is about to ask four bodies for,
        -- and a player who rests here walks down three against a board that expects four.
        --
        -- IT WAS A RECOMMENDATION FOR A PASS: both rows drawn, the ring on the paid one, the plaza's
        -- own deed satisfied by either. The rows are one row now, the panel refuses to close over an
        -- unset bone, and the press hands back to the desk -- which is where the scene that mends it
        -- is waiting (data/buildings/cathedral.lua's introAfter). A rail that any of the three escapes
        -- reopens is not one, so all three are pinned.
        name = "the coached Inn offers one row, holds the room until it is pressed, and lets go after",
        fn = function() stubFonts(function()
            local Ward = require("ui.panels.ward")
            local player = roster("character_rowan", "character_kaen")
            player.gold = Injury.TREAT_COST
            player.injuries = { character_rowan = { "injury_blood_loss" } }
            Injury.stamp(player)

            local closed = 0
            local panel = Ward.new({ player = player, coach = true,
                onClose = function() closed = closed + 1 end })
            panel:update(0)  -- the rows are laid out on the tick, not in the constructor

            assert(#panel.items == 1, "the coached morning offers one row, got " .. #panel.items)
            local i, _, kind = panel:coachIndex()
            assert(i == 1 and kind == "treat",
                "...and it is the row that sets the bone today, got " .. tostring(kind))
            assert(panel.items[i].charId == "character_rowan", "on the body that is actually hurt")

            -- THE CURSOR IS ON THE ROW THE BUBBLE NAMES. The bubble wears a key cap, and the cap is a
            -- promise about what that key does -- the same rule states/hub.lua's focusCoachedCard keeps
            -- on the plaza.
            assert(panel.menu.selected == i, "the selection sits on the coached row")

            local rect, who, drawnKind = panel:coachRect()
            assert(rect and drawnKind == "treat", "the coached visit has something to ring")
            assert(who == "character_rowan", "and it names the body, for the bubble's own token")
            local item = panel.items[i]
            assert(rect.x == item.x and rect.y == item.y and rect.w == item.w and rect.h == item.h,
                "the ring is that row and not the block")

            -- HELD. Esc, the X and the click-outside are the three ways out of every other panel in
            -- the city, and none of them answers an injury.
            assert(panel:railed(), "the room is held while the bone is unset")
            panel:keypressed("escape")
            panel:mousepressed(panel.boxX - 40, panel.boxY - 40, 1)
            panel:gamepadpressed(nil, "b")
            assert(closed == 0, "a held room cannot be walked out of, got " .. closed .. " close(s)")

            -- THE PRESS SPENDS IT: the bone is set, the rail goes with it, and the room hands back on
            -- its own -- which is the seam the house's scene plays on (models/counter.lua's introAfter).
            panel.items[i].action()
            assert(#Injury.unattended(player) == 0, "the press set the bone")
            assert(not panel:railed(), "the rail is spent with the deed")
            assert(closed == 1, "the room hands back to the desk on the press, got " .. closed)
            assert(panel:coachRect() == nil, "a body that has been seen to is no longer rung")

            -- An ordinary visit is not coached at all: no flag, no bubble, both ways out on the desk,
            -- and the door open -- which is the room every trip after this one.
            local later = roster("character_rowan")
            later.gold, later.injuries = Injury.TREAT_COST, { character_rowan = { "injury_blood_loss" } }
            Injury.stamp(later)
            local plainClosed = 0
            local plain = Ward.new({ player = later, onClose = function() plainClosed = plainClosed + 1 end })
            plain:update(0)
            assert(plain:coachRect() == nil, "an uncoached Inn draws no bubble")
            assert(not plain:railed(), "...and holds nobody")
            local rows = 0
            for _, row in ipairs(plain.items) do
                assert(row.charId and row.kind, "every row names the body and the way out it is")
                if row.charId == "character_rowan" then rows = rows + 1 end
            end
            assert(rows == 2, "a purse that covers the treatment offers both ways out, got " .. rows)
            plain:keypressed("escape")
            assert(plainClosed == 1, "and an uncoached room closes when it is asked to")
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
            player.gold = Injury.TREAT_COST - 1
            player.injuries = { character_rowan = { "injury_blood_loss" } }
            Injury.stamp(player)

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
    {
        -- ...AND THE HALF OUTSIDE THE DOOR, which is the one that has been deleted and restored.
        --
        -- The window and the row bubble above are the better teaching and they are both BEHIND a door
        -- the player has to choose to open. For a pass nothing chose it for them: the plaza's coach was
        -- cut whole, and a company walked out of Act 0 with Rowan hurt into a city where the only thing
        -- naming the room was inside the room. This pins the pointer back on the plate -- and pins that
        -- it is a pointer, since what was wrong with the old one was the eight doors it shut.
        --
        -- Read against the source, like the flag case above, because the bubble is drawn by a local in
        -- a state that cannot be loaded headless. What is checked HERE rather than in
        -- tests/hub_doors_spec.lua is the subject: that case counts the city's coach lines, this one
        -- asserts the line is the mending's and that the words it resolves to name the room and the
        -- body.
        name = "the plaza points at the mending, and turns no door down to do it",
        fn = function()
            local src = assert(love.filesystem.read("states/hub.lua"), "should be able to read the state")

            assert(src:find('Locale.coach(CITY, "ward_card")', 1, true),
                "the city no longer points at the room that answers the injury")
            assert(src:find("if coachingMend() and not activePanel", 1, true),
                "...or it points at it on a morning that is not the first one")
            -- NOT OVER THE ARRIVAL. A scene draws on top of the state rather than instead of it, so the
            -- city keeps rendering under Rowan's five lines -- and a bubble that ignored this would sit
            -- behind the scene still explaining why there is a city.
            assert(src:find("not Conversation.active", 1, true),
                "the bubble draws over the arrival scene it is supposed to follow")

            -- A POINTER, NOT A RAIL. The stage table and the door refusal are what the 2026-09-21 cut
            -- was actually about, and neither may come back with the bubble.
            -- The NAME survives in hub.lua's own history block, which is why this reads the
            -- definition rather than the word.
            assert(not src:find("INTRO_STAGES = {", 1, true),
                "the coached-card stage table is back; the bubble is not a stage")
            assert(not src:find("coachedStage", 1, true),
                "the plaza is choosing between coached cards again -- there is one line and one card")

            -- THE CURSOR IS SEATED ON THE CARD THE BUBBLE NAMES, once. The bubble wears a key cap and
            -- the cap is a promise about what that key does (the same rule the Ward's row keeps).
            assert(src:find("local function focusMendCard", 1, true),
                "nothing seats the selection on the coached card; the bubble's key cap opens another house")
            -- ...and it is seated on BOTH routes into the morning: the arrival scene's close, which is
            -- where the flag first turns over, and a later hub entry, since the first morning survives
            -- a walk out to the Gate and back. Counted off the CALLS, so the definition alone cannot
            -- satisfy this.
            local _, calls = src:gsub("    focusMendCard%(%)", "")
            assert(calls == 2,
                "focusMendCard should be called on both routes into the morning, got " .. calls)

            -- The words themselves: the plate's line names the house and the body, and leaves nothing
            -- for a token that is never passed (this line takes none -- see the bag's header).
            local text = Locale.coach(CITY_BAG, "ward_card")
            assert(text, "the plaza's line is gone from the bag")
            assert(text:find("Cathedral", 1, true), "...and it no longer names the house it points at")
            assert(text:find("Rowan", 1, true), "...or the body it is about")
            assert(not text:find("{", 1, true), "...and it leaves no token unfilled")
        end,
    },
}
