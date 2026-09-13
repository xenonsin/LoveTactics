-- Tests for the localization catalog (models/locale.lua). The model is a single grid
-- (data/lang/strings.lua): one row per stable id, a column per language, with `en` as a generated
-- mirror of the inline English source. Locale.get(key, fallback) returns the current language's cell,
-- or the inline English fallback. Renderer-free.

local Locale = require("models.locale")

return {
    {
        name = "the grid loads: rows are keyed by stable id with en + translation columns",
        fn = function()
            local grid = Locale.strings()
            assert(type(grid) == "table" and next(grid) ~= nil, "strings.lua should load a non-empty grid")
            local row = grid["name.colosseum"]
            assert(type(row) == "table", "each id maps to a row of language columns")
            assert(row.en == "The Colosseum", "the en column mirrors the English source")
            assert(row.ja == "闘技場", "the ja column holds the translation")
        end,
    },
    {
        name = "every row has an en cell (the mirror is always present)",
        fn = function()
            for key, row in pairs(Locale.strings()) do
                assert(type(row) == "table" and type(row.en) == "string" and #row.en > 0,
                    "row '" .. tostring(key) .. "' is missing its en column")
            end
        end,
    },
    {
        name = "get() uses the current language, falls back to inline English, and is identity in English",
        fn = function()
            local saved = Locale.current
            -- FOUND RATHER THAN NAMED, and that is a fix rather than a tidy-up. This pinned
            -- "line.conversation_colosseum_slot_01_intro.1" by hand, and passed for as long as it did
            -- only because the grid still carried rows for a scene that had been deleted with the Quest
            -- Board. The row was dead, the spec was reading it, and the first `. extract-strings` since
            -- pruned all 51 such scenes and took the fixture with them.
            --
            -- So: take any row that really has a ja cell. There is no key here to go stale.
            local key, english
            for k, row in pairs(Locale.strings()) do
                if type(row.ja) == "string" and #row.ja > 0 then key, english = k, row.en break end
            end
            assert(key, "no row in the grid carries a ja translation to test against")
            Locale.set("ja")
            assert(Locale.get(key, english) == Locale.raw(key, "ja"), "ja cell should win over the fallback")
            assert(Locale.get("line.does.not.exist", english) == english, "an untranslated id falls back to English")
            Locale.set("en")
            assert(Locale.get(key, english) == english, "in English, get() returns the inline fallback, not the grid")
            Locale.set(saved)
        end,
    },
    {
        name = "a blank (untranslated) cell falls back to English",
        fn = function()
            local saved, savedGrid = Locale.current, Locale.strings()
            savedGrid["__test.blank"] = { en = "English only", ja = "" }
            Locale.set("ja")
            assert(Locale.get("__test.blank", "English only") == "English only", "a blank ja cell falls back to English")
            savedGrid["__test.blank"] = nil -- clean up the probe
            Locale.set(saved)
        end,
    },
    {
        name = "key builders and languages() report the shared schema and columns",
        fn = function()
            assert(Locale.key.line("conversation_colosseum_slot_01_intro", 3) == "line.conversation_colosseum_slot_01_intro.3", "line key")
            assert(Locale.key.title("conversation_colosseum_slot_01_intro") == "title.conversation_colosseum_slot_01_intro", "title key")
            assert(Locale.key.name("colosseum") == "name.colosseum", "name key")
            assert(Locale.key.desc("knight") == "desc.knight", "blueprint description key")
            local langs = {}
            for _, l in ipairs(Locale.languages()) do langs[l] = true end
            assert(langs.en and langs.ja, "languages() should report en and ja columns")
        end,
    },
    {
        -- THE BLUEPRINT HALF OF THE CATALOG, and the reason it is asserted rather than trusted: a
        -- string authored on a blueprint reaches a translator only if something walks that registry,
        -- and nothing reports a walk that quietly collects nothing. tests/conversation_spec.lua asks
        -- exactly this of every authored LINE; this asks it of every authored class blurb.
        --
        -- Fails on a class whose description was written or rewritten without `. extract-strings`
        -- being run after -- which is the point. The row is what the translator gets, and a row still
        -- mirroring last week's English is a translation of a sentence the game no longer says.
        name = "every class description is in the grid, with its en cell in sync",
        fn = function()
            local Class = require("models.class")
            local grid = Locale.strings()
            local checked = 0
            for id, def in pairs(Class.defs) do
                if type(def.description) == "string" and def.description ~= "" then
                    local key = Locale.key.desc(id)
                    local row = grid[key]
                    assert(row, id .. ": no '" .. key .. "' row -- run `. extract-strings`")
                    assert(row.en == def.description,
                        id .. ": the grid's en cell has drifted from the blueprint -- run `. extract-strings`")
                    checked = checked + 1
                end
            end
            -- All 46 carry one today; the floor is written under that rather than at it, so adding a
            -- class is not a failing test, and deleting the walk is.
            assert(checked >= 40, "the class registry should have contributed a blurb for nearly every class")
        end,
    },
    {
        -- The seam itself: a class blurb resolves through the catalog like any authored line, and in
        -- the source language the inline English wins untouched (Locale.get is identity there), so a
        -- blueprint is never localized against its own generated mirror.
        name = "a class description resolves through the catalog and is the blueprint's own in English",
        fn = function()
            local Class = require("models.class")
            local saved, grid = Locale.current, Locale.strings()

            Locale.set("en")
            assert(Class.description("knight") == Class.defs.knight.description,
                "in English a class says exactly what its blueprint says")

            grid["desc.knight"] = grid["desc.knight"] or {}
            local savedCell = grid["desc.knight"].ja
            grid["desc.knight"].ja = "壁。"
            Locale.set("ja")
            assert(Class.description("knight") == "壁。", "a translated cell wins in that language")
            assert(Class.description("not_a_class") == nil,
                "an unknown id is still nil, in any language -- there is no English to fall back to")

            grid["desc.knight"].ja = savedCell -- leave the loaded grid as it was found
            Locale.set(saved)
        end,
    },
}
