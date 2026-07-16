-- Tests for the conversation/dialogue data layer: every data/conversations/*.lua is structurally
-- valid (cast resolves, speakers known, lines have text + a stamped id, branch targets exist), the
-- generated English template is in sync, and the branching graph-walk behaves. Renderer-free.
--
-- Nodes are authored positionally -- { "<speaker>", "<text>", tag=.., id=.., goto=.., choices={
-- {"<text>", tag=.., goto=.. }, .. } } -- and tools/extract_strings.lua stamps the `tag` ids.

local Conversation = require("models.conversation")
local Character = require("models.character")
local Vendor = require("models.vendor")
local Locale = require("models.locale")

local function nodeSpeaker(node) return node.by or node[1] end
local function nodeText(node) return node.text or node[2] end
local function choiceText(choice) return choice.text or choice[1] end

local function speakerKnown(id, override)
    if override and override.name then return true end
    return Character.defs[id] ~= nil or Vendor.defs[id] ~= nil
end

return {
    {
        name = "every conversation is structurally valid and its ids are stamped + in the en template",
        fn = function()
            local count = 0
            for id, def in pairs(Conversation.defs) do
                count = count + 1
                assert(type(def) == "table", id .. ": def is not a table")
                assert(type(def.cast) == "table" and #def.cast > 0, id .. ": needs a non-empty cast")
                assert(type(def.script) == "table" and #def.script > 0, id .. ": needs a non-empty script")

                local castIds = {}
                for _, raw in ipairs(def.cast) do
                    local entry = type(raw) == "table" and raw or { id = raw }
                    assert(speakerKnown(entry.id, entry),
                        id .. ": cast id '" .. tostring(entry.id) .. "' is not a known character/vendor")
                    castIds[entry.id] = true
                end

                local nodeIds = {}
                for _, node in ipairs(def.script) do
                    if node.id then
                        assert(not nodeIds[node.id], id .. ": duplicate node id '" .. tostring(node.id) .. "'")
                        nodeIds[node.id] = true
                    end
                end
                local function targetOk(label) return label == "end" or nodeIds[label] == true end

                -- A translatable entry must carry text, a stamped numeric `tag`, and the English
                -- template (data/lang/en.lua) must hold that exact source -- i.e. extract-strings has
                -- been run and is current. Guards against a stale template / forgotten extraction.
                local seenTags = {}
                local function checkTranslatable(entry, text, where)
                    assert(type(text) == "string" and #text > 0, where .. ": missing text")
                    assert(type(entry.tag) == "number", where .. ": missing a stamped `tag` (run extract-strings)")
                    assert(not seenTags[entry.tag], where .. ": duplicate tag " .. tostring(entry.tag))
                    seenTags[entry.tag] = true
                    local key = Locale.key.line(id, entry.tag)
                    assert(Locale.raw(key, "en") == text,
                        where .. ": en column out of sync for " .. key .. " (run extract-strings)")
                end

                for i, node in ipairs(def.script) do
                    local where = id .. " node " .. i
                    checkTranslatable(node, nodeText(node), where)
                    local by = nodeSpeaker(node)
                    assert((by and castIds[by]) or node.name, where .. ": speaker '" .. tostring(by) .. "' not in cast")
                    if node.goto then assert(targetOk(node.goto), where .. ": bad goto '" .. tostring(node.goto) .. "'") end
                    for _, choice in ipairs(node.choices or {}) do
                        checkTranslatable(choice, choiceText(choice), where .. " choice")
                        if choice.goto then assert(targetOk(choice.goto), where .. ": bad choice goto") end
                    end
                end
            end
            assert(count > 0, "no conversations were found to check")
        end,
    },
    {
        name = "nextIndex advances in order, jumps on goto, and ends",
        fn = function()
            local script = {
                { by = "a", text = "one" },
                { by = "a", text = "two" },
                { id = "far", by = "a", text = "three" },
            }
            assert(Conversation.nextIndex(script, 1, nil) == 2, "should advance 1 -> 2")
            assert(Conversation.nextIndex(script, 3, nil) == nil, "should end past the last node")
            assert(Conversation.nextIndex(script, 1, "far") == 3, "should jump to the 'far' node")
            assert(Conversation.nextIndex(script, 1, "end") == nil, "goto 'end' should finish")
            assert(Conversation.nextIndex(script, 1, "nope") == nil, "an unknown goto should finish")
        end,
    },
    {
        name = "speaker resolves name (English source) + portrait path from a blueprint",
        fn = function()
            local who = Conversation.speaker("knight")
            assert(who.name == Character.defs.knight.name, "should read the blueprint name in the source language")
            assert(who.portrait == Character.defs.knight.portrait, "should read the blueprint portrait path")
        end,
    },
    {
        name = "speaker honors an explicit name/portrait override and falls back to the id",
        fn = function()
            local o = Conversation.speaker("knight", { name = "Sir Nobody", portrait = "x.png" })
            assert(o.name == "Sir Nobody" and o.portrait == "x.png", "overrides should win")
            local u = Conversation.speaker("not_a_real_id")
            assert(u.name == "not_a_real_id" and u.portrait == nil, "unknown speaker falls back to its id")
        end,
    },
}
