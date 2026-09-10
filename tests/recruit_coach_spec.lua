-- THE FIRST COMPANION MET UNDERGROUND IS TAUGHT ON THE MAP, AND ONLY THE FIRST.
--
-- A floor's ends are all the same marker on the same kind of dead-end spur (models/errand.lua) and one
-- of them is a PERSON: the recruit the descent does not roll for, standing on floor one of every
-- descent until she joins (models/descent.lua's SCRIPTED_COMPANION). The scene at her doorway
-- introduces HER; it never says that a body met down here is how the company grows, that hearing her
-- out is free, or that the fight behind her is what keeps her. So while that first posting is
-- outstanding, states/game.lua pins a coach bubble to the marker itself (game.drawRecruitCoach).
--
-- IT IS A CONDITION, NOT A STEP. The four steps on `game.coach` are each armed at a moment and spent by
-- the player doing the thing they asked for; this one is owed by a marker standing on the board across
-- floor entries, saves, resumes and the fight itself -- and `game.coach` is wiped by every game.enter.
-- So it is read live and drawn only when no step holds the channel, which is also what makes the first
-- wound take the screen while IT is up.
--
-- None of the drawing is reachable from a headless spec -- drawCoach is a love.graphics path hanging
-- off a state that mints fonts at require-time -- so what is pinned here is what a rename or a
-- re-premise could break silently, each in the place it CAN be checked: the two lines, the gate that
-- ends the lesson, the branch that picks between them, and the anchor the bubble hangs on.

local Conversation = require("models.conversation")
local Locale = require("models.locale")
local Errand = require("models.errand")
local Descent = require("models.descent")
local Quest = require("models.quest")
local OverworldMap = require("ui.overworld_map")

local CONV = "conversation_tutorial_recruit"

local function nodeById(def, wanted)
    for _, node in ipairs(def.script or {}) do
        if node.id == wanted then return node end
    end
    return nil
end

local function source()
    return assert(love.filesystem.read("states/game.lua"), "should be able to read the state")
end

-- The body of one function of states/game.lua, so a case can say WHERE a call has to appear rather
-- than only that the file contains it somewhere.
local function functionBody(name)
    local src = source()
    local from = src:find(name, 1, true)
    if not from then return nil end
    local to = src:find("\nfunction ", from + 1)
    return src:sub(from, to or #src)
end

return {
    {
        -- THE LINES. drawRecruitCoach resolves each by node id and draws nothing when the lookup
        -- misses, so a renamed id is a lesson that silently stops happening. Pinned from both ends:
        -- the nodes exist and resolve through Locale, and the state still asks for them by name.
        name = "the recruit coach lines exist, and the overworld still asks for them by id",
        fn = function()
            local def = Conversation.defs[CONV]
            assert(def, CONV .. " is missing -- the first recruit has nothing to say")

            for _, id in ipairs({ "recruit_hint", "recruit_asked_hint" }) do
                local node = nodeById(def, id)
                assert(node, CONV .. " no longer carries a `" .. id .. "` node")
                local text = Locale.text(CONV, node)
                assert(type(text) == "string" and #text > 0, id .. " resolves to real text")

                -- IT NAMES NO BUTTON AND NO DEVICE. What this bubble asks for is a WALK, which every
                -- input already does, so it carries no {select} token -- and a line that wrote "click"
                -- itself would be lying to two of the three inputs this project supports.
                assert(not text:find("{select}", 1, true),
                    id .. " asks for a press; it should only be asking for a walk")
                assert(not text:lower():find("click", 1, true), id .. " hard-codes the mouse")

                local src = source()
                assert(src:find('hintNode(convId, asked and "recruit_asked_hint" or "recruit_hint")',
                        1, true)
                    or src:find('"' .. id .. '"', 1, true),
                    "states/game.lua no longer draws " .. id)
            end

            -- THE TWO ARE NOT THE SAME SENTENCE, which is the whole reason there are two of them: one
            -- side of the answer is an invitation, the other is a fight that has been agreed to.
            assert(Locale.text(CONV, nodeById(def, "recruit_hint"))
                ~= Locale.text(CONV, nodeById(def, "recruit_asked_hint")),
                "the two beats say the same thing -- one line would do")
        end,
    },
    {
        -- THE GATE. Taught while the game's FIRST recruit is outstanding, and that is read off her
        -- posting rather than off a new mark on the player: she is the one companion the descent does
        -- not roll for, so "she has not joined yet" is exactly "the company has never done this".
        name = "the lesson is owed until the scripted first companion has joined, and never after",
        fn = function()
            local house = Descent.SCRIPTED_COMPANION
            local opener = Errand.opener(house)
            assert(opener, "the scripted companion's house posts nothing -- retarget the gate")
            assert(Quest.defs[opener].rewardCharacter,
                "the scripted companion's opener hands over nobody")

            local player = { completedQuests = {}, errands = {} }
            assert(not Errand.doorOpen(player, house), "a fresh company still owes the first recruit")
            player.completedQuests[opener] = true
            assert(Errand.doorOpen(player, house), "clearing her posting is what ends the lesson")

            local body = functionBody("function game.drawRecruitCoach")
            assert(body, "nothing draws the recruit lesson any more -- retarget this case")
            local gate = functionBody("local function recruitLessonOwed")
            assert(gate and gate:find("Errand.doorOpen", 1, true)
                and gate:find("Descent.SCRIPTED_COMPANION", 1, true),
                "the lesson is no longer gated on the scripted companion's posting -- it would run forever")
        end,
    },
    {
        -- THE BRANCH. A recruit is two beats at ONE end (models/errand.lua): the meeting is the doorway
        -- and the ask is the room behind it, so the marker does not move between them and only the
        -- sentence does. `kind` is what picks, and a bubble still promising a free conversation after
        -- the company has agreed to the fight is the failure this pins.
        name = "the posting's own kind is what picks the line, and it flips when the ask is accepted",
        fn = function()
            local house = Descent.SCRIPTED_COMPANION
            local opener = Errand.opener(house)
            local player = { completedQuests = {}, errands = {} }

            local found = Errand.posting(player, opener)
            assert(found and found.kind == "found", "an unmet companion's end reads as an introduction")
            assert(found.vendorId == house and Errand.opener(found.vendorId) == opener,
                "the end is her house's opener, not an errand asked for over a counter")

            Errand.accept(player, opener, Descent.SCRIPTED_COMPANION_FLOOR)
            local asked = Errand.posting(player, opener)
            assert(asked and asked.kind == "asked", "saying yes turns the mark into agreed work")

            player.completedQuests[opener] = true
            assert(Errand.posting(player, opener) == nil,
                "finished work is neither, and the bubble goes with it")
        end,
    },
    {
        -- THE ANCHOR. The bubble points at a TILE, so the map has to be able to say where the camera
        -- currently has one -- and it must only ever point at a marker that is actually drawn, or the
        -- arrow teaches the player that something is somewhere it is not.
        name = "the map can point at a stop's tile, and only once that stop has been found",
        fn = function()
            local grid = { rows = 3, cols = 3, size = 32,
                cellToPixel = function(_, cx, cy) return (cx - 1) * 32, (cy - 1) * 32 end }
            local cells = {}
            for y = 1, 3 do
                cells[y] = {}
                for x = 1, 3 do cells[y][x] = { x = x, y = y } end
            end
            grid.get = function(_, x, y) return cells[y] and cells[y][x] end

            local map = setmetatable({ grid = grid, camX = 12, camY = 4 }, { __index = OverworldMap })

            -- The camera offset is the whole reason cellRect exists: the map draws under a translate,
            -- so a caller putting something of its own on a tile has to be told where it is NOW.
            local rect = map:cellRect(2, 3)
            assert(rect.x == 32 - 12 and rect.y == 64 - 4, "a tile's rect is its world pixel less the camera")
            assert(rect.w == 32 and rect.h == 32, "and it is the size of a tile")

            local cell = cells[3][2]
            assert(map:markedStop(2, 3) == nil, "unread ground carries no marker to point at")
            cell.seen = true
            assert(map:markedStop(2, 3) == nil, "found ground with no stop on it carries none either")
            cell.encounter = { kind = "objective", questId = Errand.opener(Descent.SCRIPTED_COMPANION) }
            assert(map:markedStop(2, 3) == cell, "a found stop is what the bubble is allowed to point at")
        end,
    },
}
