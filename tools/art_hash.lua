-- The fingerprint of everything composed art is a function of -- so "did anyone re-run the composer?"
-- stops being a question nobody can answer.
--
-- A composed icon is a PURE FUNCTION of its inputs, which is the property the whole pipeline is built on.
-- The corollary nobody had wired up: whenever an input moves, every output downstream of it is silently
-- wrong, and there was no way to notice. That is how 114 items ended up with no icon at all -- not a bug,
-- just an unrun regen -- and it is how a re-tier pass quietly invalidates art, since `repRank` drives both
-- the frame thickness and the row of tier pips.
--
-- So: hash the inputs, store the hash beside the output (tools/art_build.lua), and compare. Stale becomes
-- a thing a build can fail on rather than a thing somebody remembers.
--
-- What goes in, and why each one:
--
--   * the RESOLVED base slug and tint per asset -- not the layer tables themselves. Resolution runs
--     through the composer's own functions, so an edit to ELEMENT_TINT, CLASS_COLOR, FAMILY_BASE or the
--     per-item map lands here without this module having to know those tables exist. One less thing to
--     keep in sync, and it cannot go stale the way an enumerated list of tables would.
--   * repRank / class / type / boss -- the fields the pips, the pip colour and the badge read.
--   * the sprite path -- where the output lands. Repointing an item at a new file is a new output.
--   * the BYTES of every distinct base SVG resolved. This is what makes a delivered glyph under
--     art/bases/ invalidate every icon that rides on it, which is the entire point of the override.
--
-- Deliberately NOT included: anything about the PNGs on disk. This hashes what the output SHOULD be, and
-- art_build compares it against what was last built. Hashing the output too would only detect a hand-edit
-- to generated art, which is not a thing anybody should be doing.

local Registry = require("models.registry")
local Source = require("tools.icon_source")
local Icon = require("tools.icon_compose")
local Char = require("tools.char_compose")

local M = {}

-- A polynomial rolling hash, mod the Mersenne prime 2^31-1, run as two accumulators with different
-- multipliers and concatenated. Lua 5.1 has no integer type and no bitwise operators, so this stays in
-- exact double arithmetic: the widest intermediate is 8191 * (2^31-1), about 2^44, well inside the 2^53
-- a double represents exactly. Not a cryptographic hash and does not need to be -- it needs to change
-- when the input changes, and to be identical on two machines given identical input.
local PRIME = 2147483647

function M.ofString(s)
    local a, b = 5381, 52711
    for i = 1, #s do
        local c = s:byte(i)
        a = (a * 131 + c) % PRIME
        b = (b * 8191 + c) % PRIME
    end
    return string.format("%08x%08x", a, b)
end

-- Canonical serialization: every field named, every list sorted. Two runs over the same data must produce
-- byte-identical text, so nothing here may iterate a table with `pairs` without sorting the keys first --
-- Lua's hash order is not stable across runs, and an unsorted walk would make every build look stale.
local function canonical()
    local out, slugs = {}, {}

    local function field(...)
        out[#out + 1] = table.concat({ ... }, "\30")
    end

    local function note(slug)
        if slug then slugs[slug] = true end
    end

    local items = Registry.load("data/items", "data.items")
    local ids = {}
    for id in pairs(items) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local def = items[id]
        local base = Icon.baseFor(def)
        note(base)
        field("item", id,
            tostring(def.sprite),
            tostring(base),
            tostring(Icon.tintFor(def)),
            tostring(def.repRank or 0),
            tostring(def.class),
            tostring(def.type))
    end

    local chars = Registry.load("data/characters", "data.characters")
    local keys = {}
    for key in pairs(chars) do keys[#keys + 1] = key end
    table.sort(keys)
    for _, key in ipairs(keys) do
        local def = chars[key]
        local id = Char.tokenId(key)
        local slug = Char.slugFor(def, id)
        note(slug)
        field("char", key,
            tostring(def.sprite),
            tostring(slug),
            tostring(Char.tintFor(def, id)),
            tostring(def.boss and true or false))
    end

    -- The base art itself. A slug that resolves nowhere is recorded as absent rather than skipped, so the
    -- day it lands the hash moves.
    local names = {}
    for slug in pairs(slugs) do names[#names + 1] = slug end
    table.sort(names)
    for _, slug in ipairs(names) do
        local raw, root = Source.read(slug)
        field("base", slug, tostring(root), raw and M.ofString(raw) or "absent")
    end

    return table.concat(out, "\n")
end

-- The fingerprint of the current inputs, plus the count of what went into it (for a human-readable
-- manifest line -- a bare hash tells nobody anything).
function M.inputs()
    local text = canonical()
    local lines = 0
    for _ in text:gmatch("\n") do lines = lines + 1 end
    return M.ofString(text), lines + 1
end

M.canonical = canonical

return M
