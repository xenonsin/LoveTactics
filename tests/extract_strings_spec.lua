-- Tests for the conversation rewriter in tools/extract_strings.lua.
--
-- Only the pure half is exercised -- M.headerLines and M.serializeConversation -- because M.run
-- touches the source tree. That is the split tools/write_character.lua already draws, and it is the
-- half where the bug was.
--
-- The bug: the serializer regenerates a conversation file wholesale from the parsed def, and a def
-- carries no comments. So every hand-written header -- which slot a scene opens, whose refusal it is,
-- what it deliberately does not say -- was silently destroyed the moment that conversation gained a
-- line needing a tag. Nothing failed; the file simply came back shorter. These cases are the alarm.

local Extract = require("tools.extract_strings")

-- A minimal conversation def, already stamped so the shape matches what the serializer receives.
local function def()
    return {
        title = "A Scene",
        cast = { "character_avatar" },
        script = { { "character_avatar", "Hello.", tag = 1 } },
    }
end

local STANDARD = table.concat(Extract.STANDARD_HEADER, "\n")

return {
    {
        name = "an authored header is read back off the file, minus the two standard lines",
        fn = function()
            local source = STANDARD .. "\n"
                .. "--\n"
                .. "-- The opening of some quest. This sentence is the only copy.\n"
                .. "return {\n}\n"

            local header = Extract.headerLines(source)
            assert(#header == 2, "expected 2 authored lines, got " .. #header)
            assert(header[1] == "--", "the spacer comment should survive")
            assert(header[2]:find("only copy", 1, true), "the authored sentence should survive")
            for _, line in ipairs(header) do
                assert(not line:find("must not be hand-edited", 1, true),
                    "the standard header must not be duplicated into the authored block")
            end
        end,
    },
    {
        name = "the header ends at the first line of code, so body comments are not hoisted",
        fn = function()
            local source = "-- top note\nreturn {\n    -- an inline note about one line\n}\n"
            local header = Extract.headerLines(source)
            assert(#header == 1, "expected only the leading comment, got " .. #header)
            assert(header[1] == "-- top note")
        end,
    },
    {
        name = "a file with no authored header yields nothing rather than nil",
        fn = function()
            local header = Extract.headerLines(STANDARD .. "\nreturn {}\n")
            assert(type(header) == "table" and #header == 0, "expected an empty list")
        end,
    },
    {
        name = "a missing file is tolerated -- a new conversation simply has no header yet",
        fn = function()
            local header = Extract.headerLines(nil)
            assert(type(header) == "table" and #header == 0, "expected an empty list")
        end,
    },
    {
        name = "the authored header is written back out, above the def and below the standard lines",
        fn = function()
            local header = { "--", "-- Why this scene exists." }
            local text = Extract.serializeConversation(def(), header)

            assert(text:find("must not be hand-edited", 1, true), "the standard header is missing")
            assert(text:find("Why this scene exists", 1, true), "the authored header was dropped")
            assert(text:find("Why this scene exists", 1, true) < text:find("return {", 1, true),
                "the authored header must sit above the def, not inside it")

            local chunk = loadstring(text)
            assert(chunk, "the serializer emitted invalid Lua")
            local out = chunk()
            assert(out.title == "A Scene", "the def did not survive the round trip")
        end,
    },
    {
        name = "re-stamping is idempotent: a header survives being written and read a second time",
        fn = function()
            local header = { "-- The one sentence that records what this is for." }

            local once = Extract.serializeConversation(def(), header)
            -- Exactly what M.run does on the next run: read the header back off what it just wrote.
            local twice = Extract.serializeConversation(def(), Extract.headerLines(once))

            assert(once == twice, "a second pass changed the file -- the rewrite is not stable")
            local _, count = twice:gsub("The one sentence that records", "")
            assert(count == 1, "the header was duplicated on the second pass (" .. count .. " copies)")
        end,
    },
    {
        name = "serializing without a header still produces a valid file",
        fn = function()
            local text = Extract.serializeConversation(def(), nil)
            assert(loadstring(text), "the serializer emitted invalid Lua with no header")
        end,
    },
}
