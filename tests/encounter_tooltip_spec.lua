-- THE HOVER CARD FOR A STOP ON THE OVERWORLD (ui/encounter_tooltip.lua) and the query that feeds it
-- (ui/overworld_map.lua's :hoveredStop).
--
-- Driven through EncounterTooltip.blocks rather than its draw, for the reason tests/body_tooltip_spec
-- .lua gives: the block list IS what the player reads, and it reads here without a window or a font.
--
-- What this is guarding is a WIDENING. The readout it replaced named two of the twenty-two kinds of
-- mark the board draws and went silent over the rest, so the failure to catch is not a crash -- it is
-- the card quietly narrowing back to fights, which looks like nothing at all from a screenshot of a
-- floor whose nearest marker happens to be a fight.

local Encounter = require("models.encounter")
local EncounterTooltip = require("ui.encounter_tooltip")
local InputMode = require("input_mode")
local Muster = require("models.muster")
local Overworld = require("models.overworld")
local OverworldMap = require("ui.overworld_map")

-- The first block of `kind`, optionally the first whose text / label matches.
local function find(blocks, kind, label)
    for _, b in ipairs(blocks or {}) do
        if b.kind == kind and (not label or b.label == label or b.text == label) then return b end
    end
    return nil
end

local function cell(enc, cleared)
    return { x = 1, y = 1, seen = true, encounter = enc, cleared = cleared }
end

-- A :hoveredStop-capable stand-in, the shape tests/overworld_map_spec.lua uses: enough state to drive
-- the query, without the fonts and layout the real constructor builds.
local function walker(grid)
    return setmetatable({
        grid = grid, px = grid.start.x, py = grid.start.y, keysHeld = {}, cacheHaul = {},
        visionRadius = 2,
    }, { __index = OverworldMap })
end

return {
    {
        name = "a hovered stop is named, described, and headed in the colour of its own plate",
        fn = function()
            -- A MERCHANT, deliberately: it is one of the twenty the readout this replaced could not
            -- say a word about, and it is the stop whose whole content is invisible from the board.
            local blocks = EncounterTooltip.blocks(cell({ kind = "merchant", name = "Merchant" }))
            assert(blocks, "a hovered merchant describes nothing")

            local title = find(blocks, "title")
            assert(title and title.text == "Merchant", "the card does not name the stop")
            -- THE HUE IS THE TEACHING. The board separates its kinds by a plate colour and a
            -- fourteen-pixel mark; this card is the only surface that ever puts one of those beside a
            -- word, so a title headed in some other colour would teach the wrong plate.
            local r, g, b = OverworldMap.plateColor({ kind = "merchant" })
            assert(title.color and title.color[1] == r and title.color[2] == g and title.color[3] == b,
                "the card is headed in a colour no tile on the board wears")

            local desc = find(blocks, "desc")
            assert(desc and desc.text == Encounter.GLOSS.merchant,
                "the card says nothing about what a merchant is")
        end,
    },
    {
        name = "every kind of stop the board draws gets a card with words on it",
        fn = function()
            -- The coverage that matters is measured HERE and not on the gloss table: a sentence the
            -- card never reaches is a sentence nobody sees. Walks the declared list, so a kind added
            -- to the board fails this before it ships mute (tests/encounter_gloss_spec.lua).
            for _, kind in ipairs(Encounter.MARKER_KINDS) do
                -- The two marker splits are `objective`s wearing their discriminator.
                local enc = { kind = kind, name = "A Thing" }
                if kind == "quest" then enc = { kind = "objective", questId = "q", name = "A Thing" } end
                if kind == "ward" then enc = { kind = "objective", wardFor = 3, name = "A Thing" } end

                local blocks = EncounterTooltip.blocks(cell(enc))
                assert(find(blocks, "title"), kind .. " is not even named on its card")
                local desc = find(blocks, "desc")
                assert(desc and #desc.text > 0, kind .. " draws a card that says nothing")
            end
        end,
    },
    {
        name = "a stop with no encounter on it describes nothing at all",
        fn = function()
            -- The card must never become a probe the player sweeps across empty ground: it answers
            -- where a mark is drawn and nowhere else.
            assert(EncounterTooltip.blocks(cell(nil)) == nil, "bare ground was described")
            assert(EncounterTooltip.blocks(nil) == nil, "a missing cell was described")
        end,
    },
    {
        name = "a fight's card carries the three figures the decision is made against",
        fn = function()
            local enc = { kind = "combat", name = "Ambush", tier = 2 }
            local blocks = EncounterTooltip.blocks(cell(enc), {
                band = "above1", payout = "2 Iron Scrap",
            })

            local tier = find(blocks, "stat", "Tier")
            assert(tier and tier.value == "2", "the card does not say how hard the fight is rated")
            local band = find(blocks, "stat", "Against you")
            assert(band and band.value == Muster.BAND_LABEL.above1,
                "the card does not say how the fight stands to the company")
            -- THE SAME FIVE WORDS THE PIPS ARE DRAWN FROM. A card that invented its own phrasing for a
            -- band would be a second vocabulary for the one comparison the marker already draws.
            local pays = find(blocks, "stat", "Leaves")
            assert(pays and pays.value == "2 Iron Scrap", "the card does not telegraph the salvage")
        end,
    },
    {
        name = "a house's errand names the purse the first clear pays, and stops naming it once it is spent",
        fn = function()
            local enc = { kind = "objective", questId = "quest_x", name = "The Column" }
            local paid = EncounterTooltip.blocks(cell(enc), { bonus = 80 })
            local row = find(paid, "stat", "First clear pays")
            -- THE FIGURE, not the word: 80 gold is worth walking into a fight under-strength for and
            -- "bonus rewards" is not.
            assert(row and row.value == "80 gold", "the errand does not name its first-clear purse")

            -- Losing the fight spends that purse for good (models/errand.lua's Errand.fail). Every
            -- errand carries one, so the row's ABSENCE is what says it has been spent.
            local spent = EncounterTooltip.blocks(cell(enc), { bonus = nil })
            assert(not find(spent, "stat", "First clear pays"),
                "a spent purse is still being advertised")
        end,
    },
    {
        name = "a cleared stop says what is left of it, and stops pricing a decision nobody has left to make",
        fn = function()
            local enc = { kind = "treasure", name = "Treasure Chest" }
            local blocks = EncounterTooltip.blocks(cell(enc, true), { payout = "2 Iron Scrap" })
            local title = find(blocks, "title")
            assert(title and title.text == "Treasure Chest", "a spent cache stops naming itself")

            local said = {}
            for _, b in ipairs(blocks) do if b.kind == "desc" then said[#said + 1] = b.text end end
            assert(#said == 2 and said[1] == Encounter.GLOSS.treasure,
                "a spent cache no longer says what kind of thing it was")
            assert(said[2] ~= Encounter.GLOSS.treasure and #said[2] > 0,
                "a spent cache does not say it is spent")

            -- ...and none of the figures, which price a choice that is over.
            assert(not find(blocks, "stat", "Leaves"), "a spent stop still telegraphs a salvage")
        end,
    },
    {
        name = "the card answers under the pointer for a mouse and beside the company for a pad",
        fn = function()
            local grid = Overworld.generate({
                seed = 7, biome = "forest", encounterCount = 4, keyCount = 0,
                encounters = { { kind = "combat", weight = 1 } },
                objective = { name = "Boss" },
            })
            for y = 1, grid.rows do
                for x = 1, grid.cols do grid:get(x, y).seen = true end
            end
            local w = walker(grid)
            local restore = InputMode.current

            -- A stop the pointer is over, anywhere on ground the company has read.
            local far
            for y = 1, grid.rows do
                for x = 1, grid.cols do
                    local c = grid:get(x, y)
                    if not far and not c.encounter and (x ~= w.px or y ~= w.py) then far = c end
                end
            end
            far.encounter = { kind = "anvil", name = "The Cold Forge" }

            InputMode.set("mouse")
            w.hoverX, w.hoverY = far.x, far.y
            assert(w:hoveredStop() == far, "the pointer names nothing it is resting on")

            -- ...and never where nothing is drawn. `markedStop` is the marker pass's own test, so the
            -- card can never surface under mist that is hiding its tile.
            far.seen = false
            assert(w:hoveredStop() == nil, "unread ground was described")
            far.seen = true

            -- A CLEARED STOP STILL ANSWERS, unlike :hoveredFight. Those two price a decision and a
            -- spent stop has none left; this one says what a mark MEANS, and the faded plates behind a
            -- company are most of what a mapped floor is made of.
            far.cleared = true
            assert(w:hoveredStop() == far, "a cleared stop stopped explaining its own mark")
            far.cleared = nil

            -- WITH A PAD THERE IS NO POINTER, so the stop being weighed up is the one a step away --
            -- the same rule :hoveredFight has always answered by, shared now rather than copied.
            InputMode.set("gamepad")
            w.hoverX, w.hoverY = far.x, far.y
            assert(w:hoveredStop() ~= far, "a pad read a stop across the board off a stale pointer")

            local near = grid:get(w.px, w.py - 1) or grid:get(w.px, w.py + 1)
            if near then
                near.seen, near.encounter = true, { kind = "stair", name = "The Stair Down" }
                assert(w:hoveredStop() == near, "a pad names nothing on the tile it is standing beside")
            end
            InputMode.set(restore)
        end,
    },
}
