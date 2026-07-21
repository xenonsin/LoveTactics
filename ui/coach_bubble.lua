-- The tutorial's interface instruction: a small speech bubble pinned to the exact thing it is
-- talking about -- the tile to step on, the weapon to ready, the demon to strike.
--
--   CoachBubble.draw(text, rect, opts)
--     rect = { x, y, w, h }  -- the thing being pointed at, in logical 1280x720 space
--     opts = { bounds = { x, y, w, h } }  -- where the bubble is allowed to live
--
-- This is the half of the tutorial that is allowed to say "click". Its counterpart,
-- ui/tutorial_prompt.lua, carries what the mentor actually says and stays in character; keeping the
-- two apart is what lets her sound like a knight instead of a manual (see data/tutorials/village.lua).
--
-- It anchors to a RECT rather than a board cell so the same widget can point at an item slot in the
-- combat panel and at a unit on the board. The tail flips above/below to whichever side has room,
-- and the box is clamped into `bounds` while the tail stays over the target -- so a bubble pushed
-- sideways by the screen edge still visibly belongs to the thing it is naming.
--
-- No love.graphics at require-time (the font is built lazily), so it loads under the headless tests.

local Scale = require("scale")

local CoachBubble = {}

local font, keyFont
local function fonts()
    font = font or love.graphics.newFont(13)
    keyFont = keyFont or love.graphics.newFont(12)
    return font, keyFont
end

-- The key cap: a drawn button standing where an instruction would otherwise have to pick a verb.
-- Sits in its own column at the bubble's left, vertically centred against the words, so a wrapped
-- three-line instruction still reads as "<this button> <do this>" rather than losing the key in a
-- paragraph. Sized off its own label, since "Click" is four times the width of "A".
local KEY_PAD = 6   -- inside the cap, around its label
local KEY_GAP = 8   -- cap -> the words
local KEY_FILL = { 0.20, 0.18, 0.14, 1 }

local function keyCapWidth(key, kf)
    if not key then return 0 end
    return kf:getWidth(key) + KEY_PAD * 2 + KEY_GAP
end

-- The prompt's one accent: the ring around the target and the bubble's edge and text all share it,
-- so "the glowing gold thing" is a single idea the player learns once.
local GOLD = { 1.0, 0.82, 0.36 }

local MAX_W = 240
local PAD = 9
local TAIL = 10
local TAIL_HALF = 7
local RADIUS = 6
local GAP = 6 -- between the target and the tail's tip

-- A slow pulse, so the bubble reads as a live prompt rather than furniture. Subtle on purpose: it
-- sits over a board the player is trying to read.
local PULSE_SPEED = 3.4
local time = 0

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

function CoachBubble.draw(text, rect, opts)
    if not (text and rect) then return end
    opts = opts or {}
    local bounds = opts.bounds or { x = 0, y = 0, w = Scale.WIDTH, h = Scale.HEIGHT }
    local f, kf = fonts()
    local key = opts.key
    local capW = keyCapWidth(key, kf)

    time = time + love.timer.getDelta()
    local pulse = 0.5 + 0.5 * math.sin(time * PULSE_SPEED)

    -- Measure at the widest the bubble may be, then SHRINK the box to the longest line -- and lay the
    -- text out at the shrunk width, not the measured one. Printing at the measurement width into a
    -- narrower box is what spills text past the border: getWrap only reports where it would break at
    -- the width it was given. The extra pixel absorbs the rounding between measured and rendered
    -- advance widths, which is enough to push a final glyph over the edge on its own.
    -- The key cap claims its column first; the words wrap in whatever is left.
    local wrapW, lines = f:getWrap(text, MAX_W - PAD * 2 - capW)
    local w = math.min(MAX_W, math.ceil(wrapW) + 1 + PAD * 2 + capW)
    local innerW = w - PAD * 2 - capW
    local textH = #lines * f:getHeight()
    local h = PAD * 2 + math.max(textH, key and (kf:getHeight() + KEY_PAD * 2) or 0)

    -- Placement. The bubble is a prompt laid over a board the player is being taught to READ, so
    -- where it lands matters: parked above a tile in a crowded lane it hides the very unit the next
    -- instruction is about. So a board anchor tries the sides first (the flanks of a lane are empty
    -- ground), while a panel anchor tries above (a 320px column has no room beside anything).
    -- Each candidate is taken only if the whole box fits inside `bounds`; the last is a guaranteed
    -- fallback, clamped.
    local cx, cy = rect.x + rect.w / 2, rect.y + rect.h / 2
    -- The preferred side leads; the rest follow as fallbacks. A board anchor (no `prefer`) tries the
    -- flanks first (empty ground beside a lane), while a panel/HUD anchor names the side it wants.
    local PREFER_ORDER = {
        above = { "above", "below", "right", "left" },
        below = { "below", "above", "right", "left" },
        right = { "right", "left", "above", "below" },
        left  = { "left", "right", "above", "below" },
    }
    local order = PREFER_ORDER[opts.prefer] or { "right", "left", "above", "below" }

    local function horizontalSide(side) return side == "right" or side == "left" end

    -- A placement pins ONE axis; the other is free to slide along the bounds, and does. (Getting
    -- this wrong rejects perfectly good placements: an "above" bubble wider than its target is
    -- off-centre by definition, and judging it on that would throw it away and fall through to a
    -- clamped last resort sitting on top of the thing it points at.)
    local function place(side)
        local px, py
        if side == "right" then px, py = rect.x + rect.w + GAP + TAIL, cy - h / 2
        elseif side == "left" then px, py = rect.x - GAP - TAIL - w, cy - h / 2
        elseif side == "above" then px, py = cx - w / 2, rect.y - GAP - TAIL - h
        else px, py = cx - w / 2, rect.y + rect.h + GAP + TAIL end
        if horizontalSide(side) then
            py = clamp(py, bounds.y, math.max(bounds.y, bounds.y + bounds.h - h))
        else
            px = clamp(px, bounds.x, math.max(bounds.x, bounds.x + bounds.w - w))
        end
        return px, py
    end

    -- Only the pinned axis decides whether a placement is possible.
    local function fits(side, px, py)
        if horizontalSide(side) then
            return px >= bounds.x and px + w <= bounds.x + bounds.w
        end
        return py >= bounds.y and py + h <= bounds.y + bounds.h
    end

    -- Among the placements that fit, take the one that covers the least of what the player still
    -- needs to see (`opts.avoid` -- the tiles units are standing on). A fixed "always to the right"
    -- rule cannot win here: in a lane fight the free side changes from step to step, and whichever
    -- one is hardcoded will sooner or later park the bubble on a unit. Preference order breaks ties,
    -- so an empty board still lands where `prefer` asked.
    local function hidden(px, py)
        local area = 0
        for _, r in ipairs(opts.avoid or {}) do
            local ox = math.min(px + w, r.x + r.w) - math.max(px, r.x)
            local oy = math.min(py + h, r.y + r.h) - math.max(py, r.y)
            if ox > 0 and oy > 0 then area = area + ox * oy end
        end
        return area
    end

    local side, x, y, bestScore
    for _, candidate in ipairs(order) do
        local px, py = place(candidate)
        if fits(candidate, px, py) then
            local score = hidden(px, py)
            if not bestScore or score < bestScore then
                side, x, y, bestScore = candidate, px, py, score
                if score == 0 then break end -- nothing hidden; no later candidate can beat it
            end
        end
    end
    if not side then
        side = order[#order]
        x, y = place(side)
        x = clamp(x, bounds.x, math.max(bounds.x, bounds.x + bounds.w - w))
        y = clamp(y, bounds.y, math.max(bounds.y, bounds.y + bounds.h - h))
    end

    -- The tail always points back at the target, even when the box was clamped away from it, so a
    -- shoved bubble still visibly belongs to the thing it is naming.
    local bx1, by1, bx2, by2, tipX, tipY
    if horizontalSide(side) then
        local edgeX = (side == "right") and x or (x + w)
        local anchorY = clamp(cy, y + RADIUS + TAIL_HALF, y + h - RADIUS - TAIL_HALF)
        bx1, by1 = edgeX, anchorY - TAIL_HALF
        bx2, by2 = edgeX, anchorY + TAIL_HALF
        tipX = (side == "right") and (rect.x + rect.w + GAP) or (rect.x - GAP)
        tipY = anchorY
    else
        local edgeY = (side == "below") and y or (y + h)
        local anchorX = clamp(cx, x + RADIUS + TAIL_HALF, x + w - RADIUS - TAIL_HALF)
        bx1, by1 = anchorX - TAIL_HALF, edgeY
        bx2, by2 = anchorX + TAIL_HALF, edgeY
        tipX = anchorX
        tipY = (side == "below") and (rect.y + rect.h + GAP) or (rect.y - GAP)
    end

    -- A soft ring around the thing itself, so the eye lands on the target and not only on the words.
    love.graphics.setColor(GOLD[1], GOLD[2], GOLD[3], 0.30 + 0.35 * pulse)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", rect.x - 2, rect.y - 2, rect.w + 4, rect.h + 4, 4, 4)

    -- Dark fill, gold edge and gold text. A cream bubble reads as a system alert pasted over the
    -- game: it is the brightest thing on a deliberately dim screen, it fights every other panel, and
    -- the eye goes to the box instead of to the tile the box is pointing at. Dark keeps it part of
    -- the HUD; the gold is what carries "look here", and it is the same gold as the ring above.
    love.graphics.setColor(0.10, 0.09, 0.08, 0.96)
    love.graphics.rectangle("fill", x, y, w, h, RADIUS, RADIUS)
    love.graphics.polygon("fill", bx1, by1, bx2, by2, tipX, tipY)

    love.graphics.setColor(GOLD[1], GOLD[2], GOLD[3], 0.85)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, w, h, RADIUS, RADIUS)
    -- The tail's two flanks only: stroking its base would draw a line across the box's own edge.
    love.graphics.line(bx1, by1, tipX, tipY, bx2, by2)
    love.graphics.setLineWidth(1)

    -- The key cap, drawn as a button: dark plate, gold edge, gold label. Same gold as the ring and
    -- the bubble's own border, so it reads as part of the one "look here" idea rather than a fourth
    -- colour. It pulses with the border for the same reason.
    if key then
        local capH = kf:getHeight() + KEY_PAD * 2
        local capX, capY = x + PAD, y + (h - capH) / 2
        local capBoxW = kf:getWidth(key) + KEY_PAD * 2
        love.graphics.setColor(KEY_FILL[1], KEY_FILL[2], KEY_FILL[3], KEY_FILL[4])
        love.graphics.rectangle("fill", capX, capY, capBoxW, capH, 4, 4)
        love.graphics.setColor(GOLD[1], GOLD[2], GOLD[3], 0.7 + 0.3 * pulse)
        love.graphics.setLineWidth(1.5)
        love.graphics.rectangle("line", capX, capY, capBoxW, capH, 4, 4)
        love.graphics.setLineWidth(1)
        love.graphics.setFont(kf)
        love.graphics.setColor(1.0, 0.90, 0.60)
        love.graphics.printf(key, capX, capY + KEY_PAD, capBoxW, "center")
    end

    -- The words. Left-aligned when a cap sits beside them (centred text next to a fixed pill reads as
    -- a layout accident); centred when the bubble is words alone.
    love.graphics.setFont(f)
    love.graphics.setColor(0.98, 0.91, 0.72)
    local textY = y + (h - textH) / 2
    love.graphics.printf(text, x + PAD + capW, textY, innerW, key and "left" or "center")
    love.graphics.setColor(1, 1, 1)
end

return CoachBubble
