-- EVERY WORD THE TUTORIAL SAYS GOES THROUGH THE CATALOG, and this is what keeps it that way.
--
-- The teaching surfaces are the easiest place in the game for English to get typed straight into a
-- state: a bubble is one string, a window is three paragraphs, and both read perfectly well inline --
-- which is exactly how the Gate's stair bubble, the plaza's first-morning bubble and three tutorial
-- windows came to be untranslatable while every spoken line in the game was stamped, mirrored and
-- checked for drift. A string in a state is invisible to tools/extract_strings.lua, so it never
-- reaches a translator and nothing ever reports that it did not.
--
-- So all of it lives in HINT BAGS -- conversation files nobody plays in order, fetched by node id
-- (models/locale.lua's Locale.node / line / coach). Three cases here, and each pins a different half:
--
--   1. the ids the surfaces ask for exist and resolve to real text
--   2. the coaching lines are device-honest ({select}, never a written "click")
--   3. the surfaces still ask through Locale rather than carrying words of their own
--
-- The guided battle's own lesson is covered by tests/tutorial_spec.lua and the flight leg's by
-- tests/flight_leg_spec.lua; those two were already authored this way.

local Locale = require("models.locale")
local Conversation = require("models.conversation")
local Descent = require("models.descent")
local InputMode = require("input_mode")

local CITY = "conversation_tutorial_city"
local NOTES = "conversation_tutorial_notes"

-- Which surface fields which line. Kept as data so a bag that grows a line nobody reads, or a surface
-- that renames one, shows up as a named failure rather than as a bubble that quietly stops drawing.
local FIELDED = {
    { conv = CITY,  id = "gate_stair",    coach = true },
    { conv = CITY,  id = "rift_card",     coach = true },
    { conv = CITY,  id = "new_door",      coach = true },
    { conv = NOTES, id = "tally_title" },
    { conv = NOTES, id = "tally_body" },
    { conv = NOTES, id = "tactics_title" },
    { conv = NOTES, id = "tactics_body" },
    { conv = NOTES, id = "classes_title" },
    { conv = NOTES, id = "classes_body" },
    -- The window's own footer, one line per device (ui/panels/tutorial_note.lua picks the id).
    { conv = NOTES, id = "dismiss_pad" },
    { conv = NOTES, id = "dismiss_touch" },
    { conv = NOTES, id = "dismiss_key" },
}

-- InputMode is a singleton the whole suite shares; put back whatever we borrowed.
local function withMode(mode, touch, fn)
    local m, t = InputMode.current, InputMode.touch
    InputMode.current, InputMode.touch = mode, touch
    local ok, err = pcall(fn)
    InputMode.current, InputMode.touch = m, t
    assert(ok, err)
end

local function source(path)
    return assert(love.filesystem.read(path), "should be able to read " .. path)
end

return {
    {
        name = "every tutorial line a surface asks for exists, is stamped, and resolves",
        fn = function()
            for _, want in ipairs(FIELDED) do
                local where = want.conv .. "'s `" .. want.id .. "`"
                assert(Conversation.defs[want.conv], want.conv .. " is missing entirely")
                local node = Locale.node(want.conv, want.id)
                assert(node, where .. " is gone -- the surface that asks for it now draws nothing")
                assert(type(node.tag) == "number",
                    where .. " carries no stamped tag, so it can never be translated (run extract-strings)")
                local text = Locale.line(want.conv, want.id)
                assert(type(text) == "string" and #text > 0, where .. " resolves to nothing")
            end

            -- A miss is nil, never a placeholder: the caller draws nothing rather than printing an id
            -- at the player (states/game.lua's drawCoach makes the same bet).
            assert(Locale.line(NOTES, "no_such_line") == nil, "an unknown id resolves to nil")
            assert(Locale.node("no_such_conversation", "anything") == nil, "...and so does an unknown bag")
        end,
    },
    {
        -- THE COACHING HALF IS DEVICE-HONEST. Every line in the city bag is asking for a press, so
        -- every one opens with {select} -- lifted out as a key cap for a pad or keyboard, written into
        -- the sentence as the verb that device actually uses for a pointer. The same rule
        -- tests/tutorial_spec.lua applies to the village lesson's coaching, applied to the bags the
        -- city fields.
        name = "the city's bubbles name no device of their own, and resolve one per input",
        fn = function()
            for _, node in ipairs(Conversation.defs[CITY].script) do
                local authored = node.text or node[2]
                assert(authored:find("{select}", 1, true),
                    CITY .. "'s `" .. tostring(node.id) .. "` asks for a press without the {select} token")
                assert(not authored:lower():find("click", 1, true),
                    CITY .. "'s `" .. tostring(node.id) .. "` writes 'click', which is a lie on a pad")
            end

            withMode("gamepad", false, function()
                local text, key = Locale.coach(CITY, "gate_stair")
                assert(key == "A", "a pad gets a cap to draw")
                assert(not text:find("{select}", 1, true), "...and the token is lifted out of the sentence")
                assert(text:find("stair", 1, true), "the rest of the sentence survives")
            end)
            withMode("mouse", false, function()
                local text, key = Locale.coach(CITY, "gate_stair")
                assert(key == nil, "a mouse has no cap worth drawing")
                assert(text:find("Click", 1, true), "...so the verb stays in the sentence")
            end)
            withMode("mouse", true, function()
                local text = Locale.coach(CITY, "gate_stair")
                assert(text:find("Tap", 1, true), "a finger does not click")
            end)

            -- A grown door's own name is the caller's token, filled after localization so a translator
            -- can put it wherever their grammar wants it.
            withMode("mouse", false, function()
                local text = Locale.coach(CITY, "new_door", { door = "the Forge. Steel is answered here." })
                assert(text:find("the Forge.", 1, true), "the door's name reaches the bubble")
                assert(not text:find("{door}", 1, true), "...and no raw token is ever printed")
            end)
        end,
    },
    {
        -- THE FIGURES IN THE TALLY WINDOW ARE TOKENS. They are Descent's own constants, and welding one
        -- into the middle of a clause puts it somewhere a translator cannot move it AND somewhere that
        -- goes stale the day the constant does. Both halves are pinned: the line carries no digits of
        -- its own, and the state fills every token it declares.
        name = "the tally window quotes its constants as tokens, and the Gate fills them",
        fn = function()
            local authored = Locale.node(NOTES, "tally_body")
            authored = authored.text or authored[2]
            assert(not authored:find("%d"), "the tally's English has a figure typed into it")
            for _, token in ipairs({ "{stair}", "{wipe}", "{seal}", "{max}" }) do
                assert(authored:find(token, 1, true), "the tally line no longer names " .. token)
            end

            local filled = Locale.line(NOTES, "tally_body", {
                stair = Descent.COUNT_STAIR, wipe = Descent.COUNT_WIPE,
                seal = Descent.COUNT_SEAL, max = Descent.COUNT_MAX,
            })
            assert(not filled:find("{", 1, true), "every token is filled at draw time")
            assert(filled:find(tostring(Descent.COUNT_MAX), 1, true), "...with the constants themselves")

            -- The state has to still be handing those four over, or the window prints raw braces.
            local src = source("states/gate.lua")
            for _, pair in ipairs({ "stair = Descent.COUNT_STAIR", "wipe  = Descent.COUNT_WIPE",
                                    "seal  = Descent.COUNT_SEAL", "max   = Descent.COUNT_MAX" }) do
                assert(src:find(pair, 1, true), "states/gate.lua no longer fills " .. pair)
            end
        end,
    },
    {
        -- NOTHING TEACHES IN ITS OWN WORDS. A window's title and body, and a bubble's sentence, are
        -- resolved through Locale at the call site -- so the check is that no call site passes a
        -- literal. This is the case that fails the day somebody adds a fourth window the easy way.
        name = "no teaching surface carries its own English",
        fn = function()
            for _, path in ipairs({ "states/gate.lua", "states/hub.lua", "ui/panels/party.lua" }) do
                local src = source(path)
                local from = 1
                while true do
                    local at = src:find("TutorialNote.new(", from, true)
                    if not at then break end
                    local window = src:sub(at, at + 400)
                    assert(not window:find("title = \"", 1, true),
                        path .. ": a tutorial window's title is typed inline -- author it in the hint bag")
                    assert(not window:find("body = \"", 1, true),
                        path .. ": a tutorial window's body is typed inline -- author it in the hint bag")
                    from = at + 1
                end
                assert(not src:find("CoachBubble.draw(\"", 1, true),
                    path .. ": a coach bubble is drawn from a literal, which no translator can reach")
            end

            -- ...and the two panels still ask for the lines that exist, by name.
            local party = source("ui/panels/party.lua")
            for _, id in ipairs({ "tactics_title", "tactics_body", "classes_title", "classes_body" }) do
                assert(party:find(id, 1, true), "ui/panels/party.lua stopped asking for `" .. id .. "`")
            end
            local hub = source("states/hub.lua")
            assert(hub:find("\"rift_card\"", 1, true), "the first morning's bubble lost its line id")
            assert(hub:find("\"new_door\"", 1, true), "a grown door's bubble lost its line id")

            -- The window widget's footer is the one string it owns, and it must be picked as an ID
            -- rather than as three sentences (the shape this whole sweep is enforcing).
            local note = source("ui/panels/tutorial_note.lua")
            assert(note:find("InputMode.pick(\"dismiss_pad\"", 1, true),
                "the window's dismiss hint is no longer authored in the hint bag")
        end,
    },
}
