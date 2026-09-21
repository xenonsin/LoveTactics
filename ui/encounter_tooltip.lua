-- THE HOVER READOUT FOR A STOP ON THE OVERWORLD: what that mark is, in words, plus the figures a
-- player decides against. Fed by ui/overworld_map.lua's :hoveredStop, drawn by states/game.lua.
--
--   EncounterTooltip.draw(cell, ctx, mx, my)
--     ctx = { band = <muster band|nil>, payout = <salvage phrase|nil>,
--             bonus = <first-clear gold|nil> }
--
-- WHY THIS EXISTS. The board speaks in a hue and a fourteen-pixel mark -- twenty-two kinds of them --
-- and until now two of those twenty-two had words anywhere: a fight and a house's errand, named on a
-- single centred line above the map. Everything else (the cold forge that tempers a piece for nothing,
-- the stone that charges a body for its goods, the three hazards that share one colour on purpose, the
-- hole that goes down without the stair) could be read only by walking onto it and finding out. That is
-- a fine way to learn a floor once and a poor way to route across fifteen of them.
--
-- IT IS THE FIGHT'S HOVER CARD, ON THIS SCREEN. Same widget (ui/tile_tooltip.lua's `blocks` seam), same
-- corner, same 288 width -- states/battle.lua docks its tile readout at x = 16 in the bottom-left and
-- the deployment phase was corrected into line with it, so a third shape here would be the third
-- grammar for "what is under the pointer" in one game. Docked rather than floating for the same reason
-- it is docked there, and for one more of this screen's own: with a pad there is no pointer, and the
-- stop being weighed up is the one a step away (OverworldMap:weighing). A box that followed a cursor
-- would have nowhere to be for half the players.
--
-- IT REPLACED THE CENTRED LINE rather than joining it. The line said name, tier, band and salvage for a
-- fight; every one of those is a row in here, off the same functions, so keeping both would print the
-- same four facts twice on one screen -- and the second copy would be the one nobody could find.
--
-- No love.graphics at require-time.

local Encounter = require("models.encounter")
local Muster = require("models.muster")
local OverworldMap = require("ui.overworld_map")
local Scale = require("scale")
local Theme = require("ui.theme")
local TileTooltip = require("ui.tile_tooltip")

local EncounterTooltip = {}

-- The fight's own hover column: states/battle.lua's LEFT_W (320) less its 16px margins. Taken whole
-- rather than fitted to this screen -- the overworld's left column is the party strip's 218 and this
-- is not a party strip, it is the hover card, which has a size the player has already learned.
EncounterTooltip.WIDTH = 288
EncounterTooltip.DOCK_X = 16
-- How far off the foot the card's bottom sits: clear of the movement hint states/game.lua draws at
-- HEIGHT - 30. A margin rather than a Y, because Scale.HEIGHT is not a constant -- a handset held
-- upright swaps the logical axes (scale.lua), and a Y frozen at require-time would dock the card off
-- the bottom of a portrait screen.
EncounterTooltip.DOCK_MARGIN = 44

-- What a stop with no name of its own is called. Every rolled encounter carries a `name` and the
-- generator's own stops do too (models/overworld.lua, models/descent.lua), so this is the floor under
-- a hand-authored spec that forgot one rather than a routine path -- but a card headed by a bare kind
-- id ("relic_cache") is worse than one headed by nothing.
local FALLBACK_NAME = {
    quest = "Somebody's work",
    ward = "The Gate's Ward",
    objective = "The Floor's End",
}

-- A CLEARED STOP SAYS SO IN ITS OWN VOICE, because "cleared" means four different things out there and
-- the difference is the whole reason a player is looking at a faded plate: a spent cache has nothing
-- left, a dead guard has left a door open behind it. Keyed on the marker kind, so an errand and the
-- floor's end can answer differently.
local SPENT = {
    combat = "Put down. Nothing stands here now.",
    elite = "Put down. Nothing stands here now.",
    pack = "Recovered.",
    objective = "Put down -- the stair below is open.",
    quest = "Done. The house has been paid.",
    ward = "Put down -- the gate she held is open.",
    treasure = "Emptied.",
    rest = "Camped here already.",
    merchant = "Traded with.",
    anvil = "Used. A forge tempers one piece.",
    lectern = "Read. A book hones one ability.",
    crossroads = "Answered.",
    event = "Already happened.",
}

-- The blocks for the card describing `cell`, or nil when there is nothing to describe. Pure: no fonts,
-- no window, no draw -- so the words a player reads can be asserted headlessly, exactly as
-- ui/body_tooltip.lua's list is (tests/encounter_tooltip_spec.lua).
--
-- `ctx` carries the three figures this widget cannot compute for itself, because each is the state's to
-- answer and must not be recomputed here: how the fight stands to the company (game:musterBand), what
-- it salvages (game:payoutPhrase) and what a house pays for the first clear. A caller that omits one
-- simply drops that row, which is what makes the card drawable from a spec.
function EncounterTooltip.blocks(cell, ctx)
    local enc = cell and cell.encounter
    if not enc then return nil end
    ctx = ctx or {}

    local kind = Encounter.markerKind(enc)
    local blocks = {}

    local r, g, b = OverworldMap.plateColor(enc)
    blocks[#blocks + 1] = { kind = "title",
        text = enc.name or FALLBACK_NAME[kind] or "A Stop",
        color = { r, g, b } }

    local gloss = Encounter.gloss(enc)
    if gloss then blocks[#blocks + 1] = { kind = "desc", text = gloss } end

    -- WHAT IS LEFT OF IT, and it comes before the figures rather than after them: a card that opened
    -- with a tier and a salvage list and then admitted at the bottom that the fight is already over
    -- would have spent the player's reading on a decision that is not theirs to make any more.
    if cell.cleared then
        blocks[#blocks + 1] = { kind = "desc", text = SPENT[kind] or "Cleared." }
        return blocks
    end

    local rows = {}
    if enc.tier then
        rows[#rows + 1] = { kind = "stat", label = "Tier", value = tostring(enc.tier) }
    end
    -- HOW IT STANDS TO THE COMPANY, in the same five words the marker's pips and its calm wash are
    -- drawn from (Muster.BAND_LABEL). The band is the one fact on this card that is about the party
    -- rather than about the place, which is why it reads as a sentence and not as a number.
    if ctx.band then
        rows[#rows + 1] = { kind = "stat", label = "Against you",
            value = Muster.BAND_LABEL[ctx.band] or ctx.band,
            valueColor = ctx.band == "beneath" and Theme.muted or nil }
    end
    -- WHAT IT LEAVES BEHIND. Computed and never rolled (models/spoils.lua), so this is the exact payout
    -- rather than an estimate of one -- which is why gold, which carries jitter, is not named beside it.
    if ctx.payout then
        rows[#rows + 1] = { kind = "stat", label = "Leaves", value = ctx.payout }
    end
    -- THE FIRST-CLEAR PURSE on a house's errand, which is spent for good by losing the fight
    -- (models/errand.lua's Errand.fail) and is therefore weighed before committing. Once spent the row
    -- is simply absent -- every errand carries one, so its absence is the mark.
    if ctx.bonus and ctx.bonus > 0 then
        rows[#rows + 1] = { kind = "stat", label = "First clear pays",
            value = ctx.bonus .. " gold", valueColor = Theme.accentAmber }
    end

    if #rows > 0 then
        blocks[#blocks + 1] = { kind = "sep" }
        for _, row in ipairs(rows) do blocks[#blocks + 1] = row end
    end

    return blocks
end

-- Draw the card for `cell` in the bottom-left. `mx, my` are handed through only so the widget's
-- clamping has a cursor to know about; the dock is what actually places it. A no-op when there is
-- nothing under the pointer, so the caller can hand in whatever :hoveredStop returned.
function EncounterTooltip.draw(cell, ctx, mx, my)
    local blocks = EncounterTooltip.blocks(cell, ctx)
    if not blocks then return end
    return TileTooltip.draw({ blocks = blocks }, mx or 0, my or 0, Scale.WIDTH,
        { dock = true, dockX = EncounterTooltip.DOCK_X, width = EncounterTooltip.WIDTH,
          dockBottom = Scale.HEIGHT - EncounterTooltip.DOCK_MARGIN })
end

return EncounterTooltip
