-- EVERYTHING THE DOCKED COLUMN HOLDS WHILE A BLOW IS AIMED (ui/tile_tooltip.lua's dockPlan, applied
-- by states/battle.lua's drawTileTooltip).
--
-- The fight docks three things down one 288x652 column: the exchange being aimed, the body under the
-- cursor, and the ground it stands on. Terrain never yields there, so the body was the whole valve --
-- and a foe's readout, once it grew an intent section, stopped fitting beside an exchange box. The
-- effect was that pointing a weapon at an enemy deleted its armour, its reach and its pools, and
-- pointing one tile to the left brought them back: the readout went missing at exactly the moment it
-- is read.
--
-- The answer was not a better valve, it was a shorter box. The readout lays its short rows two to a
-- line (appendPairs: the eight stats, the two spendable pools, the statuses, the terrain's cost and
-- sight), the side word rides the name line, the intent heading rides the mark's line, and the
-- exchange folds its own rows the same way -- together about a third of the height, which is what
-- buys the column room for all four boxes at once.
--
-- THIS SPEC IS THE ROOM. It measures the real boxes against the real column, so a row added anywhere
-- above without a line folded to pay for it reddens here rather than silently deleting a readout in
-- front of a player. Driven through dockPlan rather than the draw, for the reason
-- tests/deploy_hover_spec.lua gives: the plan IS what the player gets, and it reads here without a
-- window.

local Scale = require("scale")
local Character = require("models.character")
local ActionPreview = require("ui.action_preview")
local TileTooltip = require("ui.tile_tooltip")

-- Face metrics MEASURED off the shipped fonts, not invented -- see tests/deploy_hover_spec.lua: a
-- stub that rounds every face to one height makes every box short enough to fit the column it does
-- not fit, and passes on the very bug it was written for.
local function withFonts(fn)
    local gfx = love.graphics
    local real = gfx.newFont
    local function face(path)
        local body = type(path) == "string" and path:find("ui%-body") ~= nil
        return {
            getHeight = function() return body and 17 or 21 end,
            getWidth = function(_, s) return #tostring(s or "") * 6 end,
            getWrap = function(self, text, limit)
                local w = self:getWidth(text)
                local out = {}
                for i = 1, math.max(1, math.ceil(w / math.max(1, limit))) do out[i] = tostring(text) end
                return math.min(w, limit), out
            end,
        }
    end
    gfx.newFont = function(path) return face(path) end
    local ok, err = pcall(fn)
    gfx.newFont = real
    if not ok then error(err, 0) end
end

local function body(id, side)
    return { char = Character.instantiate(id), side = side, alive = true, x = 1, y = 1 }
end

-- The fight's own column: LEFT_W (320) less the 16px margins its docked boxes keep, floored under the
-- shut hamburger, which is where an ordinary desktop fight docks (states/battle.lua's menuBottom).
local W, GAP, EX_GAP = 320 - 32, 8, 4
local DOCK_TOP = 16 + 36 + 8

-- What the exchange leaves of the column -- states/battle.lua's `budget`, arithmetic and all.
local function budgetAfter(exchange)
    local free = Scale.HEIGHT - 8 - DOCK_TOP
    for _, a in ipairs(exchange or {}) do free = free - ActionPreview.measure(a) - EX_GAP end
    return free
end

-- A foe hovered while the party's own turn aims a mace at it: the tables drawTileTooltip builds, and
-- the exchange that click would set off. `statuses` is what the foe is already carrying.
local function aimedAt(id, statuses)
    local foe, mine = body(id, "enemy"), body("character_rowan", "party")
    foe.statuses = statuses
    local entry = { unit = foe, damage = 12, statuses = {} }
    local action = { kind = "attack", actor = mine, target = foe, item = mine.char.inventory[1],
                     entry = entry, hit = 78, crit = 10 }
    local counter = ActionPreview.counterAction(
        { unit = foe, actor = foe, target = mine, item = foe.char.inventory[1],
          entry = { damage = 7, statuses = {} }, damage = 7 }, action)
    return { cell = { type = "forest" } },
           { unit = foe, preview = entry, intent = { kind = "attack", target = mine, amount = 9 } },
           action, counter
end

local THREE_STATUSES = {
    { def = { name = "Burning" }, remaining = 2 },
    { def = { name = "Rooted" }, remaining = 1 },
    { def = { name = "Marked" }, remaining = 3 },
}

return {
    {
        name = "aiming a blow at a foe keeps its whole readout -- stats, pools and intent alike",
        fn = function()
            withFonts(function()
                local terrain, obj, action = aimedAt("character_demon_grunt")
                local plan = TileTooltip.dockPlan(terrain, obj, W, budgetAfter({ action }), GAP)
                assert(plan.occupant, "the foe's stats went missing at the moment they are read")
                assert(plan.intent, "the intent section was shed with room still in the column")
            end)
        end,
    },
    {
        name = "the worst body in the game, aimed at with a blow it answers, still fits beside the exchange",
        fn = function()
            withFonts(function()
                -- Three pools, three statuses and a predicted turn, under a two-beat exchange: the
                -- tallest stack an ordinary fight puts in this column. It is the case the folding was
                -- done for, so it is the case pinned here.
                local terrain, obj, action, counter = aimedAt("character_mage", THREE_STATUSES)
                assert(counter, "no counter in the exchange -- this case is not testing what it says")
                local plan = TileTooltip.dockPlan(terrain, obj, W, budgetAfter({ action, counter }), GAP)
                assert(plan.occupant and plan.intent,
                    "a caster under a two-beat exchange lost part of its readout")
            end)
        end,
    },
    {
        name = "the column is not merely full: there is room left over at the tallest it gets",
        fn = function()
            withFonts(function()
                -- Measured rather than left to the plan, so this reddens when the margin is spent --
                -- BEFORE a row added upstream starts deleting readouts again. A plan-only check passes
                -- just as happily at one pixel to spare as at eighty.
                local terrain, obj, action, counter = aimedAt("character_mage", THREE_STATUSES)
                local left = budgetAfter({ action, counter })
                    - (TileTooltip.measure(obj, W) + GAP)
                    - (TileTooltip.measure(terrain, W) + GAP)
                assert(left >= 18, "only " .. left .. "px spare in the docked column -- one more row " ..
                    "anywhere above and a readout starts going missing again")
            end)
        end,
    },
    {
        name = "in a column too short for all of it, the intent yields first and the stats stand",
        fn = function()
            withFonts(function()
                -- The last resort, which now only a pathological stack reaches. The intent section is
                -- the one part of this box drawn three other places (a badge on the body, a mark on
                -- its turn card, a hover note on each), so it is the part with somewhere else to be
                -- read -- and therefore the part that goes.
                local terrain, obj = aimedAt("character_mage", THREE_STATUSES)
                local trimmed = { unit = obj.unit, preview = obj.preview }
                local budget = TileTooltip.measure(terrain, W) + GAP
                    + TileTooltip.measure(trimmed, W) + GAP
                local plan = TileTooltip.dockPlan(terrain, obj, W, budget, GAP)
                assert(plan.occupant, "the stats went with the prediction")
                assert(not plan.intent, "nothing yielded in a column measured to hold exactly the rest")
            end)
        end,
    },
    {
        name = "a column too short for even the trimmed box drops the occupant, and the ground still stands",
        fn = function()
            withFonts(function()
                local terrain, obj = aimedAt("character_mage", THREE_STATUSES)
                local plan = TileTooltip.dockPlan(terrain, obj, W, TileTooltip.measure(terrain, W) + 30, GAP)
                assert(not plan.occupant, "nothing of the body fits, so none of it is drawn")
            end)
        end,
    },
    {
        name = "dockPlan is a read: the info table it measures comes back untouched",
        fn = function()
            withFonts(function()
                local terrain, obj = aimedAt("character_mage", THREE_STATUSES)
                TileTooltip.dockPlan(terrain, obj, W, TileTooltip.measure(terrain, W) + 30, GAP)
                assert(obj.intent, "the plan must not empty the caller's own table")
            end)
        end,
    },
}
