-- Tests for the conversation/dialogue data layer: every data/conversations/*.lua is structurally
-- valid (cast resolves, speakers known, lines have text + a stamped id, branch targets exist), the
-- generated English template is in sync, conditional gating resolves coherently, and the branching
-- graph-walk behaves. Renderer-free.
--
-- Nodes are authored positionally -- { "<speaker>", "<text>", tag=.., id=.., goto=.., choices={
-- {"<text>", tag=.., goto=.. }, .. } } -- and tools/extract_strings.lua stamps the `tag` ids.
-- A script entry may instead be a conditional BLOCK ({ when = .., script = { ..nodes.. } }), which
-- these walks flatten through.

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

-- Walk every speaking node of a (possibly nested) script, handing `fn` the node and the list of
-- `when` conditions it inherits -- outermost block first, the node's own last. Those conditions are
-- exactly what must justify a gated speaker appearing in the line.
local function eachNode(entries, fn, guards)
    guards = guards or {}
    for _, entry in ipairs(entries or {}) do
        local scoped = guards
        if entry.when then
            scoped = {}
            for i, g in ipairs(guards) do scoped[i] = g end
            scoped[#scoped + 1] = entry.when
        end
        if entry.script then
            eachNode(entry.script, fn, scoped)
        else
            fn(entry, scoped)
        end
    end
end

-- A context in which everyone is recruited, every quest is done and prestige is high: the state a
-- fully-unlocked save reaches, in which every gated line should be reachable.
local function fullContext()
    local ctx = Conversation.context(nil)
    setmetatable(ctx.roster, { __index = function() return true end })
    setmetatable(ctx.quests, { __index = function() return true end })
    ctx.prestige = 99
    return ctx
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
                eachNode(def.script, function(node)
                    if node.id then
                        assert(not nodeIds[node.id], id .. ": duplicate node id '" .. tostring(node.id) .. "'")
                        nodeIds[node.id] = true
                    end
                end)
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

                local i = 0
                eachNode(def.script, function(node)
                    i = i + 1
                    local where = id .. " node " .. i
                    checkTranslatable(node, nodeText(node), where)
                    local by = nodeSpeaker(node)
                    assert((by and castIds[by]) or node.name, where .. ": speaker '" .. tostring(by) .. "' not in cast")
                    if node.goto then assert(targetOk(node.goto), where .. ": bad goto '" .. tostring(node.goto) .. "'") end
                    for _, choice in ipairs(node.choices or {}) do
                        checkTranslatable(choice, choiceText(choice), where .. " choice")
                        if choice.goto then assert(targetOk(choice.goto), where .. ": bad choice goto") end
                    end
                end)
            end
            assert(count > 0, "no conversations were found to check")
        end,
    },
    {
        -- The rule the whole gating design exists to enforce. If a cast member is conditional, every
        -- line they speak must sit under a condition that PROVES they are there -- otherwise the
        -- scene resolves with a speaker who is not on stage. Conditions are data precisely so this
        -- can be checked statically rather than discovered by a player.
        name = "a conditional cast member only ever speaks under a condition that requires them",
        fn = function()
            for id, def in pairs(Conversation.defs) do
                local gatedCast = {}
                for _, raw in ipairs(def.cast or {}) do
                    if type(raw) == "table" and raw.when then gatedCast[raw.id] = raw.when end
                end
                eachNode(def.script, function(node, guards)
                    local by = nodeSpeaker(node)
                    if not (by and gatedCast[by]) then return end
                    local guarded = false
                    for _, when in ipairs(guards) do
                        if Conversation.guarantees(when, by) then guarded = true break end
                    end
                    assert(guarded, id .. ": '" .. by .. "' is a conditional cast member but speaks a line "
                        .. "that is not inside a block requiring them -- wrap the exchange in "
                        .. "{ when = { has = \"" .. by .. "\" }, script = { .. } }")
                end)
            end
        end,
    },
    {
        -- Every authored line must be reachable by SOMEBODY, or it is dead content: a condition that
        -- no save can satisfy (a typo'd character id, a quest that was renamed) silently costs the
        -- story a scene. A fully-unlocked context must therefore keep every line.
        name = "every authored line survives resolution in a fully-unlocked context",
        fn = function()
            local ctx = fullContext()
            for id, def in pairs(Conversation.defs) do
                local authored = 0
                eachNode(def.script, function() authored = authored + 1 end)
                local resolved = Conversation.resolve(def, ctx)
                assert(#resolved.script == authored,
                    id .. ": " .. (authored - #resolved.script) .. " line(s) are unreachable even with "
                    .. "everything unlocked -- check the `when` conditions for a bad id")
                assert(#resolved.cast == #(def.cast or {}), id .. ": a cast member is unreachable")
            end
        end,
    },
    {
        name = "test evaluates the condition grammar against a context",
        fn = function()
            local ctx = { roster = { character_priest = true }, quests = { vault_heist = true }, prestige = 2 }
            assert(Conversation.test(nil, ctx), "no condition is unconditional")
            assert(Conversation.test({ has = "character_priest" }, ctx), "priest is on the roster")
            assert(not Conversation.test({ has = "character_mage" }, ctx), "mage is not")
            assert(Conversation.test({ notHas = "character_mage" }, ctx), "notHas inverts")
            assert(Conversation.test({ done = "vault_heist" }, ctx), "quest is completed")
            assert(not Conversation.test({ done = "arena_debut" }, ctx), "uncompleted quest fails")
            assert(Conversation.test({ notDone = "arena_debut" }, ctx), "notDone inverts")
            assert(Conversation.test({ prestige = 2 }, ctx), "prestige is a MINIMUM, so equal passes")
            assert(not Conversation.test({ prestige = 3 }, ctx), "below the minimum fails")
            assert(Conversation.test({ has = "character_priest", done = "vault_heist" }, ctx), "sibling keys AND")
            assert(not Conversation.test({ has = "character_priest", prestige = 9 }, ctx), "one failing key fails the AND")
            assert(Conversation.test({ any = { { has = "character_mage" }, { has = "character_priest" } } }, ctx), "any is an OR")
            assert(not Conversation.test({ all = { { has = "character_mage" }, { has = "character_priest" } } }, ctx), "all is an AND")
            local ok = pcall(Conversation.test, { hass = "character_priest" }, ctx)
            assert(not ok, "a typo'd condition key must raise, never silently pass")
        end,
    },
    {
        name = "guarantees proves a condition requires a character, conservatively",
        fn = function()
            assert(Conversation.guarantees({ has = "character_priest" }, "character_priest"), "a direct has")
            assert(not Conversation.guarantees({ has = "character_mage" }, "character_priest"), "a different character")
            assert(not Conversation.guarantees({ done = "vault_heist" }, "character_priest"), "an unrelated condition")
            assert(Conversation.guarantees({ all = { { done = "x" }, { has = "character_priest" } } }, "character_priest"),
                "an `all` holds only if every member does, so one member requiring the priest is enough")
            assert(not Conversation.guarantees({ any = { { has = "character_priest" }, { done = "x" } } }, "character_priest"),
                "an `any` can hold via the other branch, so it guarantees nothing")
            assert(Conversation.guarantees({ any = { { has = "character_priest" }, { has = "character_priest", done = "x" } } }, "character_priest"),
                "an `any` whose every branch requires the priest does guarantee them")
        end,
    },
    {
        name = "resolve drops a gated block and re-points a goto that aimed into it",
        fn = function()
            local def = {
                cast = { "character_knight", { id = "character_priest", when = { has = "character_priest" } } },
                script = {
                    { "character_knight", "one", id = "start", goto = "banter" },
                    { when = { has = "character_priest" }, script = {
                        { "character_priest", "two", id = "banter" },
                        { "character_knight", "three" },
                    } },
                    { "character_knight", "four", id = "tail" },
                },
            }

            local withPriest = Conversation.resolve(def, { roster = { character_priest = true }, quests = {}, prestige = 1 })
            assert(#withPriest.cast == 2, "the priest is on stage when recruited")
            assert(#withPriest.script == 4, "every line plays")
            assert(withPriest.script[1].goto == "banter", "the goto is left alone")

            local without = Conversation.resolve(def, { roster = {}, quests = {}, prestige = 1 })
            assert(#without.cast == 1 and without.cast[1] == "character_knight", "the priest is off stage")
            assert(#without.script == 2, "the whole banter block leaves, not just the priest's line")
            assert(without.script[2][2] == "four", "the surviving lines keep their order")
            assert(without.script[1].goto == "tail",
                "a goto into a dropped block re-points to the next surviving line, not off the end")
        end,
    },
    {
        name = "resolve redirects to 'end' when nothing survives after the dropped node",
        fn = function()
            local def = {
                cast = { "character_knight", { id = "character_priest", when = { has = "character_priest" } } },
                script = {
                    { "character_knight", "one", goto = "last", choices = { { "go", goto = "last" } } },
                    { when = { has = "character_priest" }, script = { { "character_priest", "two", id = "last" } } },
                },
            }
            local r = Conversation.resolve(def, { roster = {}, quests = {}, prestige = 1 })
            assert(#r.script == 1, "only the knight's line survives")
            assert(r.script[1].goto == "end", "a goto with no surviving successor ends the scene")
            assert(r.script[1].choices[1].goto == "end", "a choice's goto is redirected too")
            assert(def.script[1].goto == "last", "the blueprint itself must not be mutated")
        end,
    },
    {
        name = "resolve gives a synthetic id to a surviving redirect target that lacks one",
        fn = function()
            local def = {
                cast = { "character_knight", { id = "character_priest", when = { has = "character_priest" } } },
                script = {
                    { "character_knight", "one", goto = "gone" },
                    { when = { has = "character_priest" }, script = { { "character_priest", "two", id = "gone" } } },
                    { "character_knight", "three" }, -- no id of its own, but must be jumpable to
                },
            }
            local r = Conversation.resolve(def, { roster = {}, quests = {}, prestige = 1 })
            local target = r.script[1].goto
            assert(target and target ~= "end", "the jump should land on the surviving line")
            assert(Conversation.nextIndex(r.script, 1, target) == 2, "and the walk should reach it")
        end,
    },
    {
        name = "a nested block cannot escape a dropped parent",
        fn = function()
            local def = {
                cast = { "character_knight", { id = "character_priest", when = { has = "character_priest" } } },
                script = {
                    { when = { has = "character_priest" }, script = {
                        { "character_priest", "outer" },
                        { when = { prestige = 1 }, script = { { "character_priest", "inner" } } },
                    } },
                },
            }
            local r = Conversation.resolve(def, { roster = {}, quests = {}, prestige = 5 })
            assert(#r.script == 0, "the inner block's own condition passes, but its parent's does not")
        end,
    },
    {
        name = "context reads roster, completed quests and prestige off a player",
        fn = function()
            local ctx = Conversation.context({
                roster = { { id = "character_knight" }, { id = "character_priest" } },
                completedQuests = { vault_heist = true },
                prestige = 4,
            })
            assert(ctx.roster.character_knight and ctx.roster.character_priest, "roster ids are flattened to a set")
            assert(ctx.roster.character_mage == nil, "an absent character is absent")
            assert(ctx.quests.vault_heist == true and ctx.prestige == 4, "quests and prestige carry over")
            local empty = Conversation.context(nil)
            assert(next(empty.roster) == nil and empty.prestige == 1, "no player is an empty context")
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
            local who = Conversation.speaker("character_knight")
            assert(who.name == Character.defs.character_knight.name, "should read the blueprint name in the source language")
            assert(who.portrait == Character.defs.character_knight.portrait, "should read the blueprint portrait path")
        end,
    },
    {
        name = "speaker honors an explicit name/portrait override and falls back to the id",
        fn = function()
            local o = Conversation.speaker("character_knight", { name = "Sir Nobody", portrait = "x.png" })
            assert(o.name == "Sir Nobody" and o.portrait == "x.png", "overrides should win")
            local u = Conversation.speaker("not_a_real_id")
            assert(u.name == "not_a_real_id" and u.portrait == nil, "unknown speaker falls back to its id")
        end,
    },
}
