-- Localization catalog. ONE grid table -- data/lang/strings.lua -- with a row per string id and a
-- column per language:
--
--   ["line.wrath_intro.1"] = { en = "So. Fresh blood ...", ja = "ほう、砂場に ..." },
--   ["name.colosseum"]     = { en = "The Colosseum",        ja = "闘技場" },
--
-- This is the "localization spreadsheet" layout (id | en | ja | ...): a translator sees English and
-- their language in the same row, and a blank cell is an obvious gap. The `en` column is a MIRROR --
-- English is authored inline (in conversations, blueprints) and the grid is generated/merged by
-- tools/extract_strings.lua; the game never reads `en` at runtime. See docs/localization.md.
--
-- Kept require-safe (a plain data require, no love.graphics), so it loads under the headless tests.

local Locale = {}

Locale.DEFAULT = "en"
Locale.current = Locale.DEFAULT

local grid   -- { [id] = { en = .., ja = .. } }, loaded once
local langs  -- sorted list of the columns present (always includes "en")

-- Load (and memoize) the grid, plus the set of languages it declares. A missing/broken file yields
-- an empty grid, so every lookup simply falls back to the inline English.
local function load()
    if grid then return grid end
    local ok, t = pcall(require, "data.lang.strings")
    grid = (ok and type(t) == "table") and t or {}
    local set = { [Locale.DEFAULT] = true }
    for _, row in pairs(grid) do
        for lang, v in pairs(row) do
            if type(v) == "string" then set[lang] = true end
        end
    end
    langs = {}
    for l in pairs(set) do langs[#langs + 1] = l end
    table.sort(langs)
    return grid
end

-- The whole grid (for the extraction tool and tests).
function Locale.strings()
    return load()
end

-- Every language the grid declares (a column present in any row), sorted; always includes "en".
function Locale.languages()
    load()
    return langs
end

function Locale.set(lang)
    Locale.current = lang or Locale.DEFAULT
end

-- The raw cell for a key in a specific language, or nil when the row or that column is absent.
function Locale.raw(key, lang)
    local row = load()[key]
    return row and row[lang or Locale.current]
end

-- Resolve a stable-ID key, falling back to the inline English the author wrote. In the source
-- language we return `fallback` directly and never consult the grid -- the inline text is
-- authoritative and can never drift from the generated `en` column. In any other language we return
-- that language's cell, or the English fallback when the cell is missing or blank (untranslated).
-- This is the runtime half of the stable-ID / extraction model (tools/extract_strings.lua).
function Locale.get(key, fallback)
    if Locale.current == Locale.DEFAULT then return fallback end
    local row = load()[key]
    local v = row and row[Locale.current]
    if v and v ~= "" then return v end
    return fallback
end

-- The key schema, shared by the runtime and the extraction tool so they always agree. Ids are stable:
-- a line's `tag` is stamped into the conversation file and never changes once assigned.
Locale.key = {
    line = function(conv, tag) return "line." .. conv .. "." .. tostring(tag) end,
    title = function(conv) return "title." .. conv end,
    name = function(id) return "name." .. id end,
}

return Locale
