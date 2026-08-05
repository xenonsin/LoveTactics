-- The forge track: an item's whole upgrade path drawn as a CHAIN OF NODES rather than a table of
-- numbers. One node per level 0..MAX, joined by connectors, with the rung the player stands on filled
-- and the rungs past their standing dashed out.
--
--   local layout = ForgeTrack.layout(x, y, w, { level = 3, ceiling = 8, max = 10, aim = 4 })
--   ForgeTrack.draw(layout)
--   local lvl = ForgeTrack.hit(layout, mx, my)   -- the level under the pointer, or nil
--
-- It replaces ui/growth_ladder.lua, which drew the same path as an 11-row x N-column spreadsheet --
-- every stat's value at every level, all of it on screen at once. The numbers were exact and nobody
-- read them: the questions actually being asked at a bench are "where am I", "how far can I go" and
-- "what does the next one buy", and only the third of those is a number. The first two are a shape,
-- so they are drawn as one, and the caller answers the third in its compare band against `aim`.
--
-- FIVE STATES, and each is legible from FORM before colour is read (a filled node, a hollow node, a
-- dashed node), because colour alone is the one encoding a player cannot check:
--   owned    a rung already paid for      filled, quiet bronze
--   now      where the item stands        filled amber + a halo, the one spotlight on the strip
--   next     the very next rung           hollow, gain-green rim
--   future   reachable, not yet bought    hollow, hairline rim
--   locked   past the standing ceiling    dashed rim, dimmed -- a wall, not a step
--
-- THREE MARKS, and they are three different questions, so none of them may look like another:
--   now    where the item stands            amber, warm, the fixed fact
--   aim    the rung the player has PICKED   solid steel ring -- chosen, and what the button will buy
--   hover  the rung the pointer is over     faint steel ring -- being considered, committing to nothing
-- Steel rather than amber for the latter two per Theme.cursor: a screen showing a fixed "where I am"
-- beside a moving "where I'm pointing" needs warm-vs-cool to keep them apart. Aim and hover are then
-- told apart by WEIGHT rather than hue, because they are the same kind of thing at two strengths.
--
-- Pure layout + draw, no state of its own: the panel owns `aim` and hands it in every frame.

local Theme = require("ui.theme")

local ForgeTrack = {}

local NODE = 40      -- a node's box; the diamond is drawn inside it
local GAP = 14       -- connector length between two nodes
local LABEL_H = 14   -- the "+n" caption under each node
local CAP_H = 12     -- the NOW / NEXT marker over the two that carry one

ForgeTrack.NODE = NODE
ForgeTrack.GAP = GAP
-- What ForgeTrack.layout will occupy vertically, so a caller can reserve the band before laying out.
ForgeTrack.HEIGHT = CAP_H + NODE + 2 + LABEL_H

-- The widest a track of `max + 1` rungs wants. A caller with less width than this still gets a valid
-- layout -- the nodes simply tighten -- but this is the size at which it reads best.
function ForgeTrack.naturalWidth(max)
    local n = (max or 10) + 1
    return n * NODE + (n - 1) * GAP
end

-- Lay the chain out inside `w`, squeezing the GAPS (never the nodes) when the band is narrow, so a
-- node never becomes too small to click. Returns { x, y, w, h, node, step, rungs = { {level,x,y,w,h} } }.
function ForgeTrack.layout(x, y, w, opts)
    opts = opts or {}
    local max = opts.max or 10
    local n = max + 1
    local gap = GAP
    if n * NODE + (n - 1) * gap > w then
        gap = math.max(4, (w - n * NODE) / math.max(1, n - 1))
    end
    local step = NODE + gap

    local rungs = {}
    local top = y + CAP_H
    for i = 0, max do
        rungs[#rungs + 1] = { level = i, x = x + i * step, y = top, w = NODE, h = NODE }
    end
    return {
        x = x, y = y, w = w, h = ForgeTrack.HEIGHT,
        node = NODE, step = step, max = max, rungs = rungs,
        level = opts.level or 0, ceiling = opts.ceiling or max,
        aim = opts.aim, hover = opts.hover,
    }
end

-- Which state a rung is in. Order matters: `locked` outranks everything, because a rung past the
-- ceiling is a wall whether or not it happens to be the next one up.
local function stateOf(lvl, level, ceiling)
    if lvl > ceiling then return "locked" end
    if lvl < level then return "owned" end
    if lvl == level then return "now" end
    if lvl == level + 1 then return "next" end
    return "future"
end

local GAIN = { 0.55, 0.90, 0.58 } -- the rung the button buys: kept heal-green (semantic, not chrome)

-- A diamond inscribed in the rung's box -- the node shape. Drawn as a polygon rather than a rotated
-- rectangle so the fill and the rim land on the same geometry at any size.
local function diamond(r, inset)
    local cx, cy = r.x + r.w / 2, r.y + r.h / 2
    local d = r.w / 2 - (inset or 0)
    return cx, cy - d, cx + d, cy, cx, cy + d, cx - d, cy
end

-- A dashed diamond rim, for a rung past the ceiling: the wall reads as a wall without needing colour.
local function dashedDiamond(r, inset)
    local cx, cy = r.x + r.w / 2, r.y + r.h / 2
    local d = r.w / 2 - (inset or 0)
    local pts = { { cx, cy - d }, { cx + d, cy }, { cx, cy + d }, { cx - d, cy } }
    for i = 1, 4 do
        local a, b = pts[i], pts[i % 4 + 1]
        -- three dashes an edge, the middle third left open
        for _, seg in ipairs({ { 0, 0.30 }, { 0.38, 0.62 }, { 0.70, 1 } }) do
            love.graphics.line(a[1] + (b[1] - a[1]) * seg[1], a[2] + (b[2] - a[2]) * seg[1],
                a[1] + (b[1] - a[1]) * seg[2], a[2] + (b[2] - a[2]) * seg[2])
        end
    end
end

function ForgeTrack.draw(layout, opts)
    if not layout then return end
    opts = opts or {}
    local level, ceiling, aim, hover = layout.level, layout.ceiling, layout.aim, layout.hover
    local capFont = opts.capFont or Theme.body(10)
    local numFont = opts.numFont or Theme.body(12)
    local lw = love.graphics.getLineWidth()

    -- Connectors first, under the nodes: filled bronze up to where the item stands, hairline after.
    for i = 1, #layout.rungs - 1 do
        local a, b = layout.rungs[i], layout.rungs[i + 1]
        local x1, x2 = a.x + a.w, b.x
        local cy = a.y + a.h / 2
        Theme.set(b.level <= level and Theme.frame or Theme.hairline)
        love.graphics.rectangle("fill", x1, cy - 1, x2 - x1, 2)
    end

    for _, r in ipairs(layout.rungs) do
        local st = stateOf(r.level, level, ceiling)
        love.graphics.setLineWidth(1.5)

        if st == "owned" then
            Theme.set(Theme.frame, 0.42)
            love.graphics.polygon("fill", diamond(r, 4))
            Theme.set(Theme.frame)
            love.graphics.polygon("line", diamond(r, 4))
        elseif st == "now" then
            -- the one spotlight: a filled amber node with a soft halo, so "you are here" is found first
            Theme.set(Theme.accentAmber, 0.20)
            love.graphics.polygon("fill", diamond(r, 0))
            Theme.set(Theme.accentAmber)
            love.graphics.polygon("fill", diamond(r, 4))
        elseif st == "next" then
            Theme.set(Theme.slot)
            love.graphics.polygon("fill", diamond(r, 4))
            love.graphics.setColor(GAIN[1], GAIN[2], GAIN[3])
            love.graphics.polygon("line", diamond(r, 4))
        elseif st == "locked" then
            Theme.set(Theme.mount, 0.7)
            love.graphics.polygon("fill", diamond(r, 4))
            Theme.set(Theme.frame, 0.45)
            dashedDiamond(r, 4)
        else -- future
            Theme.set(Theme.slot)
            love.graphics.polygon("fill", diamond(r, 4))
            Theme.set(Theme.hairline)
            love.graphics.polygon("line", diamond(r, 4))
        end

        -- The two steel rings, told apart by weight: solid for the rung that is PICKED, faint for the
        -- one merely under the pointer. Drawn exclusively -- a hover resting on the picked rung is one
        -- ring, not two stacked -- so "chosen" never gets quietly thickened by the mouse sitting on it.
        if aim and r.level == aim and aim ~= level then
            Theme.set(Theme.cursor)
            love.graphics.setLineWidth(2)
            love.graphics.polygon("line", diamond(r, 1))
        elseif hover and r.level == hover and hover ~= level then
            Theme.set(Theme.cursor, 0.5)
            love.graphics.setLineWidth(1.5)
            love.graphics.polygon("line", diamond(r, 1))
        end

        -- The level number, inside the node.
        love.graphics.setFont(numFont)
        if st == "now" then Theme.set(Theme.mount)
        elseif st == "next" then love.graphics.setColor(GAIN[1], GAIN[2], GAIN[3])
        elseif st == "locked" then Theme.set(Theme.frame, 0.5)
        elseif st == "owned" then Theme.set(Theme.ink, 0.75)
        else Theme.set(Theme.muted, 0.8) end
        local label = r.level == 0 and "0" or ("+" .. r.level)
        love.graphics.printf(label, r.x, r.y + r.h / 2 - numFont:getHeight() / 2, r.w, "center")

        -- NOW / NEXT over the two rungs that carry a marker; everything else stays quiet.
        if st == "now" or st == "next" then
            love.graphics.setFont(capFont)
            if st == "now" then Theme.set(Theme.accentAmber)
            else love.graphics.setColor(GAIN[1], GAIN[2], GAIN[3]) end
            love.graphics.printf(st == "now" and "NOW" or "NEXT", r.x - 8, layout.y, r.w + 16, "center")
        end
    end

    -- Where the wall is, named once under the first rung past it rather than on every locked node.
    if ceiling < layout.max then
        local first = layout.rungs[ceiling + 2]
        if first then
            love.graphics.setFont(capFont)
            Theme.set(Theme.muted, 0.8)
            love.graphics.printf("standing", first.x - 10, first.y + first.h + 2, first.w + 20, "center")
        end
    end

    love.graphics.setLineWidth(lw)
    love.graphics.setColor(1, 1, 1)
end

-- The level under (mx, my), or nil. Hit-tests the whole rung box rather than the drawn diamond: a
-- diamond is a small target and the corners between two of them belong to nobody.
function ForgeTrack.hit(layout, mx, my)
    if not layout then return nil end
    for _, r in ipairs(layout.rungs) do
        if mx >= r.x and mx <= r.x + r.w and my >= r.y and my <= r.y + r.h then
            return r.level
        end
    end
    return nil
end

return ForgeTrack
