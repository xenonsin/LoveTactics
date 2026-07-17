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
            local key, english = "line.conversation_wrath_intro.1", "So. Fresh blood ..."
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
            assert(Locale.key.line("conversation_wrath_intro", 3) == "line.conversation_wrath_intro.3", "line key")
            assert(Locale.key.title("conversation_wrath_intro") == "title.conversation_wrath_intro", "title key")
            assert(Locale.key.name("colosseum") == "name.colosseum", "name key")
            local langs = {}
            for _, l in ipairs(Locale.languages()) do langs[l] = true end
            assert(langs.en and langs.ja, "languages() should report en and ja columns")
        end,
    },
}
