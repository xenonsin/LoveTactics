-- THE INTENT MARK SAYS WHAT IT MEANS (ui/combat_panel.lua's CombatPanel.intentNote).
--
-- A foe's coming turn is drawn on its turn-order card as a coloured glyph and a bare number, which is
-- the right density for a corner of a 34px card and no help at all to a player who has not yet learned
-- which of five shapes is a spell. The card as a whole opens the body's full readout under the cursor;
-- the MARK is its own hover target with its own short answer, the way the wait figure two rows above
-- it is.
--
-- Driven through intentNote rather than the draw, for the reason tests/wait_note_spec.lua gives: the
-- lines ARE what the player reads, and they read here without a window or a font. What this file
-- guards:
--
--   * the opening line is Intent.GLOSS's and nothing else -- the SAME sentence the body readout
--     prints, because two boxes glossing one mark in two accounts is how a player learns to trust
--     neither;
--   * that sharing is real, not a copy that happens to match today (the last case reads
--     ui/tile_tooltip.lua's own source and fails if the sentences move back into it);
--   * the figure is LABELLED by its verb -- a bare number beside an icon cannot say whether it is
--     damage dealt or healing given -- and is absent wherever the mark quotes none.

local CombatPanel = require("ui.combat_panel")
local Intent = require("models.intent")

local function joined(lines) return table.concat(lines, " ") end

-- A body to be come for. Only the name is ever read, but it is read off `char`, so the shape matters.
local function body(name)
    return { char = { name = name }, side = "party", alive = true, x = 1, y = 1 }
end

-- The reading, with its opening sentence checked against the shared one. Every case wants both, and
-- the check is the whole point of the file, so it is not left to be remembered case by case.
local function noteFor(intent)
    local title, lines = CombatPanel.intentNote(intent)
    local kind = intent.kind or "wait"
    assert(lines[1] == Intent.GLOSS[kind].desc,
        "the mark opens on its own sentence rather than the shared one:\n  note:   "
            .. tostring(lines[1]) .. "\n  shared: " .. tostring(Intent.GLOSS[kind].desc))
    return title, lines
end

return {
    {
        name = "every kind the classifier can produce has a word and a sentence to be glossed with",
        fn = function()
            for _, kind in ipairs(Intent.KINDS) do
                local def = Intent.GLOSS[kind]
                assert(def, "the " .. kind .. " intent has no gloss, so its mark reads as nothing")
                assert(type(def.name) == "string" and def.name ~= "",
                    "the " .. kind .. " intent has no word")
                assert(type(def.desc) == "string" and def.desc:find("%.") ~= nil,
                    "the " .. kind .. " gloss is not a sentence: " .. tostring(def.desc))
            end
        end,
    },
    {
        name = "a strike names the word, who it comes for, and what it deals",
        fn = function()
            local title, lines = noteFor({ kind = "attack", target = body("Rowan"), amount = 8 })
            assert(title == "Intent: Attack", "the note is titled " .. tostring(title))
            assert(joined(lines):find("Target: Rowan", 1, true), "it does not say who: " .. joined(lines))
            assert(joined(lines):find("Deals 8", 1, true), "it does not say how hard: " .. joined(lines))
        end,
    },
    {
        name = "a cast reads as an ability, not an attack, and rounds its figure the way the card does",
        fn = function()
            local title, lines = noteFor({ kind = "cast", target = body("Xin"), amount = 6.4 })
            assert(title == "Intent: Ability", "the note is titled " .. tostring(title))
            assert(joined(lines):find("Deals 6", 1, true), "the figure is not the card's: " .. joined(lines))
        end,
    },
    {
        name = "a support cast HEALS -- the verb, not the number, is what says who the figure happens to",
        fn = function()
            local _, lines = noteFor({ kind = "support", target = body("Ren"), heal = 5 })
            local text = joined(lines)
            assert(text:find("Heals 5", 1, true), "a heal reads as: " .. text)
            assert(not text:find("Deals", 1, true), "a heal is reported as damage: " .. text)
        end,
    },
    {
        name = "a debuff quotes no figure: its mark already says 'a status', and there is no number on the card",
        fn = function()
            local _, lines = noteFor({ kind = "debuff", target = body("Rowan"), amount = 0, statuses = 1 })
            local text = joined(lines)
            assert(text:find("Target: Rowan", 1, true), "it does not say who: " .. text)
            assert(not (text:find("Deals", 1, true) or text:find("Heals", 1, true)),
                "a debuff invents a figure the card never drew: " .. text)
        end,
    },
    {
        name = "a hold says only that it acts on nobody -- no target row about an absence",
        fn = function()
            local title, lines = noteFor({ kind = "wait", wait = true })
            assert(title == "Intent: Wait", "the note is titled " .. tostring(title))
            assert(#lines == 1, "a hold prints " .. #lines .. " lines: " .. joined(lines))
        end,
    },
    {
        name = "a target with no name still reads, and no reading ever prints a nil or a raw id",
        fn = function()
            for _, kind in ipairs(Intent.KINDS) do
                local _, lines = noteFor({ kind = kind, target = { char = {} }, amount = 3, heal = 3 })
                local text = joined(lines)
                assert(not text:find("nil", 1, true), kind .. " prints a nil into its reading: " .. text)
                assert(not text:find("table:", 1, true), kind .. " leaks a table: " .. text)
            end
        end,
    },
    {
        name = "the body readout prints the shared sentences rather than keeping its own copy of them",
        fn = function()
            -- THE SHARING HAS TO BE STRUCTURAL. Every case above compares the note's opening line to
            -- Intent.GLOSS, which proves the note reads it -- and proves nothing whatever about
            -- ui/tile_tooltip.lua, where these five sentences were born and where a copy of them would
            -- go on matching for exactly as long as nobody edited either side. So the file is read:
            -- the sentences must be GONE from it, and the shared table named in their place.
            local src = assert(love.filesystem.read("ui/tile_tooltip.lua"), "ui/tile_tooltip.lua is readable")
            assert(src:find("Intent.GLOSS", 1, true),
                "the body readout no longer reads the shared intent gloss at all")
            for kind, def in pairs(Intent.GLOSS) do
                local opener = def.desc:sub(1, 20)
                assert(not src:find(opener, 1, true),
                    "the " .. kind .. " sentence has been written back into ui/tile_tooltip.lua ('"
                        .. opener .. "...'), so the card and the body can drift again")
                assert(not src:find('"' .. def.name .. '"', 1, true),
                    "the " .. kind .. " word has been written back into ui/tile_tooltip.lua")
            end
        end,
    },
}
