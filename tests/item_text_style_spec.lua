-- Tests for the item-text STYLE contract (docs/item-text.md).
--
-- tests/item_schema_spec.lua guards the cheap facts: description and flavor both exist, they
-- differ, description is under its length ceiling. This sweep guards the *style* rules that used
-- to be aspirational -- the ones that let the corpus drift into card-game rules text that wasn't:
--
--   * vague duration/magnitude filler ("for a while", "far more") the tooltip's own rows already
--     carry -- a card never says "for a while";
--   * two phrasings of the same forever-duration ("for the rest of the battle" vs "this battle") --
--     collapse to one;
--   * a named status buried in a lowercase verb ("poisons it", "roots it") instead of the
--     capitalized noun ("inflicts Poison", "inflicts Root") the glossary is standing by to define.
--
-- Curated on purpose: the leak list holds only verbs that, used as whole words in rules text, are
-- almost always the game status -- not every lowercase word that could match a keyword. The doc
-- carries the judgment calls; this catches the regressions.
--
-- Pure logic, headless. Sweep style mirrors tests/item_schema_spec.lua's eachItem().

local Item = require("models.item")
local Status = require("models.status")
local Trait = require("models.trait")

-- Display names of every status, for the "name it, don't re-explain it" check. A "<Status>:" in a
-- description is the tell that the line restates the definition the glossary column already renders
-- (models/glossary.lua builds that column from the ability's EFFECT, not from this text, so the
-- restatement is pure duplication). Plain, case-sensitive find on "<Name>:" -- narrow on purpose:
-- "gain Blessed." never trips it, "leaves them Exposed: ..." does.
local STATUS_NAMES = {}
for _, def in pairs(Status.defs) do
    if type(def.name) == "string" then STATUS_NAMES[#STATUS_NAMES + 1] = def.name end
end
table.sort(STATUS_NAMES)

-- Prose frames a rules-text line must never open with -- lead with the verb, move framing to flavor.
-- `Toggle:` and `Channeled:` are EXEMPT: they are mechanical keyword prefixes (a toggled stance, a
-- wind-up), not flavor framing, so they are deliberately absent here.
local BANNED_LEADS = { "Triggered:", "Passive:", "Active:" }

-- Substrings banned outright (case-insensitive, plain find). Vague timing and vague magnitude.
local BANNED = {
    "for a while",
    "a short while",
    "for a time",
    "briefly",
    "for most of the battle",
    "most of the battle",
    "for the rest of the battle", -- say "this battle"
    "a sliver",
    "far more",
    "far deeper",
    "greater power",
}

-- Whole-word lowercase leaks: a named status hiding in a lowercase verb ("it roots the foe")
-- instead of its capitalized noun ("inflicts Root"). Matched CASE-SENSITIVELY on purpose -- a
-- capitalized reference to a status the target already has ("a Frozen or Stunned foe", "immune to
-- Rooted") is legitimate and must pass; only the lowercase verb form is a leak. Kept conservative --
-- every entry is a verb that in rules text means the status. (Omits "burns"/"marks": literal English.)
local LEAKS = {
    "poisons", "poisoning",
    "roots", "rooted",
    "soaks", "soaked",
    "stuns", "stunned",
    "blinds", "blinded",
    "bleeds",
}

-- Healing is written "heal", never mend/mends/mending/mended (docs/item-text.md) -- in EVERY authored
-- string, not only rules text. Whole-word, case-insensitive.
--
-- This used to carve out names and flavor, and shipped a Totem of Mending under the exemption. That
-- taught the mechanic under two words at once: the shelf said Mending, the tooltip said heals. The
-- carve-out is gone, the totem is named for the ground it lays (Totem of Renewal), and there is one
-- word for putting health back.
local MEND_WORDS = { "mend", "mends", "mending", "mended" }

local function eachItem()
    local out = {}
    for id, def in pairs(Item.defs) do out[#out + 1] = { id = id, def = def } end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

-- Every description string an item exposes: the item's own, plus a signature ability's.
local function descriptions(def)
    local out = {}
    if type(def.description) == "string" then out[#out + 1] = def.description end
    local ab = def.activeAbility
    if ab and type(ab.description) == "string" then out[#out + 1] = ab.description end
    return out
end

-- Every authored string an item exposes, descriptions plus the name and flavor. A rule about how the
-- game says a mechanic holds over all four; the rules-text-only rules above keep reading descriptions().
local function allText(def)
    local out = descriptions(def)
    if type(def.name) == "string" then out[#out + 1] = def.name end
    if type(def.flavor) == "string" then out[#out + 1] = def.flavor end
    return out
end

return {
    {
        name = "no description uses vague duration or magnitude filler (docs/item-text.md)",
        fn = function()
            for _, it in ipairs(eachItem()) do
                for _, desc in ipairs(descriptions(it.def)) do
                    local low = desc:lower()
                    for _, phrase in ipairs(BANNED) do
                        assert(not low:find(phrase, 1, true),
                            it.id .. ' says "' .. phrase .. '" -- a card never times an effect that'
                                .. ' way; use a controlled duration or let the tooltip row carry it'
                                .. ' (docs/item-text.md)')
                    end
                end
            end
        end,
    },
    {
        name = "a named status is written as its capitalized noun, not a lowercase verb",
        fn = function()
            for _, it in ipairs(eachItem()) do
                for _, desc in ipairs(descriptions(it.def)) do
                    for _, word in ipairs(LEAKS) do
                        -- Case-sensitive, whole-word (%f frontier): only the lowercase verb leaks,
                        -- never a capitalized "Rooted"/"Stunned" reference to a foe's own status.
                        assert(not desc:find("%f[%a]" .. word .. "%f[%A]"),
                            it.id .. ' buries a status in "' .. word .. '" -- name it as the'
                                .. ' capitalized noun the glossary defines (docs/item-text.md)')
                    end
                end
            end
        end,
    },
    {
        name = "healing is written \"heal\" -- never mend -- in name, flavor and rules text alike",
        fn = function()
            local function scan(kind, id, text)
                local low = text:lower()
                for _, word in ipairs(MEND_WORDS) do
                    assert(not low:find("%f[%a]" .. word .. "%f[%A]"),
                        kind .. " " .. id .. ' says "' .. word .. '" -- healing is written as "heal"'
                            .. ' everywhere: name, flavor and rules text (docs/item-text.md)')
                end
            end
            for _, it in ipairs(eachItem()) do
                for _, text in ipairs(allText(it.def)) do scan("item", it.id, text) end
            end
            -- Traits and statuses were never covered, and under the old carve-out that is exactly where
            -- the word survived: Grave-Cold read "Mending does not reach the dead" and the Unspent Heart
            -- "Mends hard while untouched" -- both of them rules text, in the badge tooltip the player
            -- reads mid-fight.
            for _, source in ipairs({ { "trait", Trait.defs }, { "status", Status.defs } }) do
                for id, def in pairs(source[2]) do
                    for _, key in ipairs({ "name", "description" }) do
                        if type(def[key]) == "string" then scan(source[1], id, def[key]) end
                    end
                end
            end
        end,
    },
    {
        name = "a named status is not re-explained -- no \"<Status>:\" restatement (docs/item-text.md)",
        fn = function()
            for _, it in ipairs(eachItem()) do
                for _, desc in ipairs(descriptions(it.def)) do
                    for _, name in ipairs(STATUS_NAMES) do
                        assert(not desc:find(name .. ":", 1, true),
                            it.id .. ' re-explains ' .. name .. ' ("' .. name .. ':") -- name the'
                                .. ' status and stop; its definition already renders in the glossary'
                                .. ' beside the tooltip (docs/item-text.md)')
                    end
                end
            end
        end,
    },
    {
        name = "no description opens with a banned prose frame (Triggered:/Passive:/Active:) (docs/item-text.md)",
        fn = function()
            for _, it in ipairs(eachItem()) do
                for _, desc in ipairs(descriptions(it.def)) do
                    for _, lead in ipairs(BANNED_LEADS) do
                        assert(desc:sub(1, #lead) ~= lead,
                            it.id .. ' opens with "' .. lead .. '" -- lead with the verb and move'
                                .. ' the framing to flavor (docs/item-text.md)')
                    end
                end
            end
        end,
    },
}
