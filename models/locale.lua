-- Localization catalog. ONE grid table -- data/lang/strings.lua -- with a row per string id and a
-- column per language:
--
--   ["line.conversation_wrath_intro.1"] = { en = "So. Fresh blood ...", ja = "ほう、砂場に ..." },
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

-- What `{select}` stands for on each device: the button that acts on whatever the cursor is over.
--
-- These are KEY CAPS, not words. An instruction that says "Click" is a lie on two of this project's
-- three supported inputs -- but writing a verb for each ("Click" / "Hit Enter on" / "Press A on")
-- only produces three sentences saying the same picture, and the awkward one is always somebody's.
-- A drawn key reads instantly, needs no grammar, and survives translation untouched: the noun after
-- it is the whole sentence a translator has to think about.
--
-- ui/coach_bubble.lua renders this as a pill; anything printing plain text gets the label inline as
-- a graceful fallback, so a surface that cannot draw a key never prints a raw `{select}`.
--
-- THE MOUSE IS NOT IN THIS TABLE, and that is the point of the split. "Click" is not a key -- drawn
-- as a cap it invents a button nobody owns, and a player who goes looking for it on their mouse has
-- been handed a puzzle by the one thing on screen whose whole job was to be unambiguous. A pad's A
-- and a keyboard's Enter really are labelled buttons, and a picture of them beats any sentence. So
-- the two devices with something to draw get the cap, and the mouse gets the plain English verb it
-- has always had.
local SELECT_KEY = {
    keyboard = "Enter",
    gamepad = "A",
}

-- What a POINTER says instead, written into the sentence like any other word. A finger is in the
-- same position as a mouse and for the same reason -- there is no cap to draw, because there is no
-- button -- but it is emphatically not the same word: a handset told to "Click on the grunt" is
-- being instructed by the one thing on screen whose whole job was to be unambiguous.
local SELECT_WORD = "Click"
local SELECT_WORD_TOUCH = "Tap"

-- The key cap for the device in the player's hands, or nil when it has no button worth drawing
-- (the mouse). A nil here is what tells the caller to render words rather than a pill.
function Locale.selectKey()
    return SELECT_KEY[require("input_mode").current]
end

-- ...and for the pointing devices, which have no cap to draw: the verb their own hardware uses.
function Locale.selectWord()
    return require("input_mode").touch and SELECT_WORD_TOUCH or SELECT_WORD
end

-- Substitute the runtime tokens an authored line may carry:
--
--   {name}   -- the name the player typed at character creation, so a companion can address the
--               avatar directly (Rowan is sworn to you and calls you by it from the first scene).
--               An unset name falls back to the avatar blueprint's "Stranger".
--   {discipline} -- the display name of the discipline a vendor is announcing as newly unlocked
--               (states/hub.lua). Set on the active player for the scene's duration, like {name}.
--   {select} -- the confirm verb for the device in the player's hands RIGHT NOW (see above). It
--               re-resolves on every draw, so a player who puts down the mouse and picks up a pad
--               mid-lesson sees the instruction change under them rather than being told to click.
--
-- Runs AFTER localization on purpose -- the tokens travel through the translated string, so a
-- translator moves them to wherever their grammar wants them.
--
-- Lives here, beside the key schema, because it is the OTHER half of the text-resolution rule and
-- more than one surface renders authored lines now (the dialogue box and the tutorial's speech
-- bubble). A second copy of the token spelling is exactly the drift docs/localization.md warns about.
-- Required lazily so this module stays a plain data require under the headless tests.
function Locale.substitute(text)
    if text:find("{name}", 1, true) then
        local p = require("models.player").active
        text = text:gsub("{name}", (p and p.name) or "Stranger")
    end
    if text:find("{discipline}", 1, true) then
        -- The display name of the discipline a shop is currently announcing (states/hub.lua sets it
        -- on the active player just before playing the scene, and clears it after). Read the same way
        -- {name} reads the avatar's name, so a single "the shelf just grew" scene per vendor can speak
        -- any discipline. Falls back to a plain word if nothing is being announced.
        local p = require("models.player").active
        text = text:gsub("{discipline}", (p and p.announcingDiscipline) or "a new discipline")
    end
    if text:find("{house}", 1, true) or text:find("{posting}", 1, true) then
        -- The house whose work the company is standing on, and what its posting says -- set on the
        -- player for the scene's duration exactly as {discipline} is (states/game.lua's askErrand),
        -- so ONE "somebody posted this" scene speaks for all seven houses. The fallbacks are what a
        -- line reads as if it plays with nothing posted, which is a bug rather than a state: they are
        -- written to be sentences rather than to be noticed.
        --
        -- Replaced through a FUNCTION rather than a string, because a posting is authored prose rather
        -- than a name: a description carrying a `%` would be read as a capture reference by gsub and
        -- come back mangled or throw.
        local p = require("models.player").active
        local house = (p and p.postingHouse) or "a house in the city"
        local work = (p and p.postingWork) or "Work, and no more said about it."
        text = text:gsub("{house}", function() return house end)
        text = text:gsub("{posting}", function() return work end)
    end
    if text:find("{select}", 1, true) then
        text = text:gsub("{select}", Locale.selectKey() or Locale.selectWord())
    end
    return text
end

-- An authored entry's display text: the current language's translation (keyed by the stable `tag`
-- the extraction tool stamped) falling back to the inline English, with runtime tokens substituted.
-- `entry` is a conversation node or choice. Accepts both the authored shape -- { "speaker", "text" },
-- where the line is positional -- and the normalized `text =` one, since callers reach it from either
-- side of ui/dialogue.lua's normalization (the same `n.text or n[2]` the extraction tool reads).
local function localized(convId, entry)
    if not entry then return "" end
    local english = entry.text or entry[2] or ""
    if entry.tag == nil then return english end
    return Locale.get(Locale.key.line(convId, entry.tag), english)
end

function Locale.text(convId, entry)
    return Locale.substitute(localized(convId, entry))
end

-- A coaching line, resolved for the device in the player's hands. Returns `text, key`:
--
--   gamepad   "{select} on the imp to strike it."  ->  "on the imp to strike it.", "A"
--   keyboard                                       ->  "on the imp to strike it.", "Enter"
--   mouse                                          ->  "Click on the imp to strike it.", nil
--   touch                                          ->  "Tap on the imp to strike it.", nil
--
-- Two shapes because the devices genuinely differ (see SELECT_KEY): a pad and a keyboard have a
-- labelled button, so the token is lifted OUT of the sentence for ui/coach_bubble.lua to draw as a
-- pill; a pointer does not, so the verb stays in the sentence as ordinary words and there is no cap.
-- Which verb comes from Locale.selectWord -- a finger has no cap to draw either, but it does not
-- click.
--
-- A line that does not open with the token comes back whole, and Locale.substitute has already
-- turned any inner `{select}` into its label -- so nothing ever prints a raw token.
function Locale.coachLine(convId, entry)
    local raw = localized(convId, entry)
    local key = Locale.selectKey()
    if not key then return Locale.substitute(raw), nil end
    return Locale.substitute((raw:gsub("^%s*{select}%s*", ""))), key
end

-- ---------------------------------------------------------------------------
-- Hint bags: authored lines that are not scenes
-- ---------------------------------------------------------------------------
--
-- A HINT BAG is a conversation file nobody plays in order. Each node carries an `id` and is fetched one
-- at a time by whatever surface owns it -- a coach bubble pinned to a card, the body of a tutorial
-- window. data/conversations/tutorial/ holds them all.
--
-- WHY A CONVERSATION FILE AND NOT A STRING IN THE STATE. Because that is where the extraction tool
-- looks (tools/extract_strings.lua): a line put there is stamped with a stable tag, mirrored into the
-- grid, checked for drift by tests/conversation_spec.lua and translated with no wiring of its own. A
-- string typed into a state is none of those things -- it is simply English, forever, and invisible to
-- everything that measures how much of this game a translator can reach. See docs/localization.md.
--
-- Three surfaces read them: the overworld coach (states/game.lua), the city's and the Gate's bubbles
-- (states/hub.lua, states/gate.lua) and the tutorial windows (ui/panels/tutorial_note.lua's callers).
-- The guided battle's lesson reads its own lines the same way, through models/tutorial.lua.

-- The authored node carrying `id` in a conversation, or nil. Indexed once per conversation and
-- memoized: a bubble asks for its line every frame it is drawn.
--
-- Walks nested `when` blocks rather than indexing the top level, so a hint that later needs a
-- condition around it does not silently stop resolving. Conversation is required lazily -- it requires
-- THIS module, and a file-scope require either way would be a cycle.
local nodeIndex = {}
function Locale.node(convId, nodeId)
    if not (convId and nodeId) then return nil end
    local index = nodeIndex[convId]
    if not index then
        index = {}
        local def = require("models.conversation").defs[convId]
        local function walk(entries)
            for _, entry in ipairs(entries or {}) do
                if entry.script then walk(entry.script)
                elseif entry.id then index[entry.id] = entry end
            end
        end
        walk(def and def.script)
        nodeIndex[convId] = index
    end
    return index[nodeId]
end

-- THE CALLER'S OWN TOKENS, filled in after the line has been localized -- `{ stair = 2, max = 8 }`
-- turns `{stair}` and `{max}` into those figures wherever the translator has moved them.
--
-- A SECOND TOKEN CHANNEL, beside Locale.substitute's, and the split is the point: that one knows the
-- fixed handful a SCENE may carry ({name}, {discipline}, ...), all of them read off the active player.
-- These are the caller's -- a balance constant the window is quoting, the name of the door a bubble is
-- pointing at -- and the alternative to passing them is a number welded into the middle of a sentence
-- where no translator can reach it (which is exactly what the Tally window used to be).
--
-- Replaced through a function so a value carrying `%` cannot be read back as a capture reference, for
-- the reason {posting} gives above.
local function fill(text, tokens)
    if not (text and tokens) then return text end
    for name, value in pairs(tokens) do
        local v = tostring(value)
        text = text:gsub("{" .. name .. "}", function() return v end)
    end
    return text
end

-- One hint's display text, localized and with its tokens substituted, or nil when no node carries that
-- id. NIL RATHER THAN A PLACEHOLDER on purpose: an id renamed out from under a caller is an authoring
-- slip, and the honest failure is a bubble that does not draw (states/game.lua's drawCoachLesson makes
-- the same call).
function Locale.line(convId, nodeId, tokens)
    local node = Locale.node(convId, nodeId)
    return node and fill(Locale.text(convId, node), tokens) or nil
end

-- ...and the coaching form of the same lookup: `text, key`, with a leading {select} lifted out for the
-- bubble to draw as a key cap (see Locale.coachLine).
function Locale.coach(convId, nodeId, tokens)
    local node = Locale.node(convId, nodeId)
    if not node then return nil end
    local text, key = Locale.coachLine(convId, node)
    return fill(text, tokens), key
end

return Locale
