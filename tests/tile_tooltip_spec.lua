-- THE INTENT SECTION on a body's readout (ui/tile_tooltip.lua): the words behind the mark.
--
-- A foe's coming turn is drawn twice on the screen and captioned nowhere -- a glyph and a bare number
-- on its turn card (ui/combat_panel's drawIntentRead) and the same pair on its body (ui/battle_map's
-- drawIntentBadge). The hover readout is where that mark is glossed, and states/battle.lua opens the
-- SAME readout from both of those surfaces (battle.drawUnitTooltip for the card, drawTileTooltip's
-- occupant box for the body), so one section serves both.
--
-- Driven through TileTooltip.blocks rather than its draw, for the reason tests/body_tooltip_spec.lua
-- gives: the block list IS what the player reads, and it reads here without a window or a font.

local Character = require("models.character")
local Colors = require("ui.colors")
local Glyphs = require("ui.glyphs")
local Intent = require("models.intent")
local TileTooltip = require("ui.tile_tooltip")

-- A bare combat unit: enough of one for the readout, which asks for a name, a side and some stats.
local function body(id, side)
    return { char = Character.instantiate(id or "character_rowan"), side = side or "party",
             alive = true, x = 1, y = 1 }
end

-- The first block of `kind`, optionally the first whose label / name / text matches `label`.
--
-- A `stat` is looked for INSIDE paired rows as well as among the full-width blocks. The readout lays
-- short rows two to a line to fit the column it docks into (ui/tile_tooltip.lua's appendPairs), and
-- which half of which line a row landed on is a fitting decision, not a reading one -- a spec that
-- could only see the full-width rows would call a paired "Deals" missing and fail on the layout
-- rather than on the words.
local function find(blocks, kind, label)
    local function matches(b)
        return not label or b.label == label or b.name == label or b.text == label
    end
    for _, b in ipairs(blocks) do
        if b.kind == kind and matches(b) then return b end
        if kind == "stat" and b.kind == "pair" then
            for _, half in ipairs({ b.left, b.right }) do
                if half and matches(half) then return half end
            end
        end
    end
end

return {
    {
        name = "a hovered body glosses the intent mark: the kind's own word, who it comes for, and what it lands",
        fn = function()
            local foe, mark = body("character_demon_grunt_tutorial", "enemy"), body("character_rowan", "party")
            local blocks = TileTooltip.blocks({ unit = foe,
                intent = { kind = "attack", target = mark, amount = 12.4 } })

            local row = find(blocks, "intent")
            assert(row, "the section names no kind")
            -- The section is LABELLED, wherever the label sits: it shares the mark's own row rather
            -- than taking a heading line above it, but a mark with no word for what it is answering
            -- is the thing this section exists to prevent.
            assert(row.label == "Intent", "the intent row carries no heading")
            assert(row.name == "Attack", "attack is glossed as " .. tostring(row.name))
            -- The mark taught here must be the mark worn out there: the same glyph and the same tint
            -- the card and the board badge look up, not a second drawing of the same idea.
            assert(Glyphs.INTENT[row.glyphKind] == Glyphs.INTENT.attack, "a different glyph than the badge wears")
            assert(row.color == Colors.INTENT.attack, "a different tint than the target line wears")

            local target = find(blocks, "stat", "Target")
            assert(target and target.value == mark.char.name, "the section names no target")
            -- The figure the badge quotes, LABELLED -- a bare number cannot say whether it is damage
            -- dealt or healing given, which is the whole reason this section exists. And labelled with
            -- the VERB: this box already carries the unit's own "Damage" stat row, so the blow's figure
            -- cannot wear that word too.
            local dmg = find(blocks, "stat", "Deals")
            assert(dmg and dmg.value == "12", "the blow reads " .. tostring(dmg and dmg.value))
            assert(not find(blocks, "stat", "Heals"), "a strike quotes healing too")
            local stat = find(blocks, "stat", "Damage")
            assert(stat and stat.value ~= "12", "the blow's figure took the Damage stat row's label")
        end,
    },
    {
        name = "a support intent quotes its figure as healing, never as damage",
        fn = function()
            local healer, ally = body("character_priest", "enemy"), body("character_rowan", "enemy")
            local blocks = TileTooltip.blocks({ unit = healer,
                intent = { kind = "support", target = ally, amount = 0, heal = 9 } })
            local row = find(blocks, "intent")
            assert(row and row.name == "Support", "support is glossed as " .. tostring(row and row.name))
            local heal = find(blocks, "stat", "Heals")
            assert(heal and heal.value == "9", "healing reads " .. tostring(heal and heal.value))
            assert(not find(blocks, "stat", "Deals"), "a heal quotes damage")
        end,
    },
    {
        name = "a hold names nobody and quotes no figure",
        fn = function()
            local foe = body("character_demon_grunt_tutorial", "enemy")
            local blocks = TileTooltip.blocks({ unit = foe, intent = { kind = "wait", wait = true } })
            local row = find(blocks, "intent")
            assert(row and row.name == "Wait", "a hold is glossed as " .. tostring(row and row.name))
            assert(not find(blocks, "stat", "Target"), "a hold names a target")
            assert(not find(blocks, "stat", "Deals") and not find(blocks, "stat", "Heals"),
                "a hold quotes a figure")
            -- The sentence is the only thing a hold has to say, so it had better be there.
            assert(find(blocks, "desc"), "a hold says nothing at all")
        end,
    },
    {
        name = "a body with no prediction gets no Intent section",
        fn = function()
            -- Your own bodies are never predicted, and neither is anybody at all with the preference
            -- off (computeIntents leaves the cache empty): the section must vanish rather than draw a
            -- heading over nothing.
            local blocks = TileTooltip.blocks({ unit = body("character_rowan", "party") })
            assert(not find(blocks, "intent"), "an intent row with no intent behind it")
        end,
    },
    {
        name = "every intent kind is glossed by a word of its own",
        fn = function()
            -- A new kind added to models/intent.lua with no entry here would fall back to the hold's
            -- word, and a foe about to do something new would read as one coming for nobody. Uniqueness
            -- is what catches that: the fallback collides with Wait's own row.
            local seen = {}
            for _, kind in ipairs(Intent.KINDS) do
                local blocks = TileTooltip.blocks({ unit = body("character_demon_grunt_tutorial", "enemy"),
                    intent = { kind = kind } })
                local row = find(blocks, "intent")
                assert(row and row.name, "no word for intent kind " .. kind)
                assert(not seen[row.name], "intent kind " .. kind .. " borrows the word for " ..
                    tostring(seen[row.name]))
                seen[row.name] = kind
                assert(Glyphs.INTENT[kind], "intent kind " .. kind .. " has no mark")
                assert(Colors.INTENT[kind], "intent kind " .. kind .. " has no tint")
                -- One flat sentence per kind, and a different one each time: the row's word and the
                -- sentence under it are what separate a Spell from an Attack.
                local desc = find(blocks, "desc")
                assert(desc and desc.text and #desc.text > 0, "intent kind " .. kind .. " says nothing")
            end
        end,
    },
}
