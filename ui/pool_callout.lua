-- The pool-preview CALLOUT: the one blueprint every surface uses to quote what an aimed action
-- would LEAVE a resource pool at. A floating pill carrying the pool's own glyph and the projected
-- value, with a tick sitting on the bar at the level the fill is about to settle to.
--
-- It replaced the inline "cur -> after / max" arrow text that used to live in the value column,
-- which made the numbers jump about every time the aim moved. The pill floats in a pass of its own
-- so two pools changing at once (a spell that costs mana AND heals) stack clear of each other
-- instead of colliding inside the tight row pitch the bars are packed at.
--
-- The pill must read the same wherever a pool is previewed -- the acting card's stack
-- (ui/combat_panel.lua) and the hover tooltip's stack (ui/tile_tooltip.lua) are the same statement
-- about the same numbers -- so the geometry, the font, and the colours all live here rather than
-- being restated per widget. No love.graphics at require-time.
--
--   local callouts = PoolCallout.new()
--   callouts:add{ anchorX =, anchorY =, barH =, key = "stamina", text = "52", color =, alpha = }
--   callouts:draw(clampLeft, clampRight)   -- after every bar, so the pills layer over them
--
-- `anchorX` is the x the bar's fill will settle at (the edge the pending slice ends on); `anchorY`
-- is the bar's top and `barH` its thickness, so the tick can cut through it.
--
-- `aboveY` (optional) floors the pill higher than its bar: a surface that can RESERVE a lane for the
-- pill (a laid-out tooltip box, as against the panel's fixed card pitch) passes the top of the row,
-- so the pill sits in the space made for it rather than over the row's own numbers. The leader still
-- runs down to the anchor, so it says which bar it speaks for either way.

local Glyphs = require("ui.glyphs")

local PoolCallout = {}
PoolCallout.__index = PoolCallout

PoolCallout.H = 16
local PAD_X = 5
local ICON_W = 7
local GAP = 3   -- clearance kept between the pill and the bar, and between two stacked pills
local TIP = 5   -- height of the caret sitting on the bar at the projected level

local font
local function pillFont()
    font = font or love.graphics.newFont(12)
    return font
end

function PoolCallout.new()
    return setmetatable({ list = {} }, PoolCallout)
end

-- Queue one projection. Cheap enough to call from inside a bar-drawing loop; nothing is drawn until
-- draw() runs, which is what lets the placement pass see every pill at once.
function PoolCallout:add(c)
    c.alpha = c.alpha or 1
    self.list[#self.list + 1] = c
    return self
end

function PoolCallout:isEmpty() return #self.list == 0 end

-- Empty the queue without drawing (a caller that rebuilds its callouts every frame).
function PoolCallout:clear() self.list = {} end

-- The box a pill fills, so the placement pass can test it for overlap before drawing it.
function PoolCallout.size(text)
    return PAD_X * 2 + ICON_W + 3 + pillFont():getWidth(text), PoolCallout.H
end

-- Draw every queued projection, then empty the queue. Call after the bars so the pills layer over
-- them. `clampL`/`clampR` bound the pills horizontally (the owning panel's inner edges) so one never
-- hangs off the surface it belongs to.
--
-- Preferred spot is directly above its bar, centred on the level the bar will settle at. Rows are
-- packed closer than a pill is tall, so each pill is pushed UP until it clears every one already
-- placed, and a leader runs back down to its own bar. That way the pills never smear over each other
-- and each still says which bar it belongs to.
function PoolCallout:draw(clampL, clampR)
    local list = self.list
    if #list == 0 then return end
    love.graphics.setFont(pillFont())
    -- Bottom-most bar first: the lowest row keeps the spot nearest its own bar, and rows above it
    -- stack further up, so the leaders never cross.
    table.sort(list, function(a, b) return a.anchorY > b.anchorY end)
    local placed = {}
    for _, c in ipairs(list) do
        local w, h = PoolCallout.size(c.text)
        local x = math.max(clampL, math.min(c.anchorX - w / 2, clampR - w))
        local y = (c.aboveY or (c.anchorY - TIP)) - GAP - h
        local moved = true
        while moved do
            moved = false
            for _, p in ipairs(placed) do
                if x < p.x + p.w + GAP and p.x < x + w + GAP
                    and y < p.y + p.h + GAP and p.y < y + h + GAP then
                    y = p.y - GAP - h
                    moved = true
                end
            end
        end
        placed[#placed + 1] = { x = x, y = y, w = w, h = h, c = c }
    end
    -- Every marker and leader first, then every pill: a pill pushed high has to reach past the pills
    -- below it to get to its bar, and that leader must pass BEHIND them rather than ruling a line
    -- across their faces.
    for _, p in ipairs(placed) do PoolCallout.drawMark(p.x, p.y, p.w, p.h, p.c) end
    for _, p in ipairs(placed) do PoolCallout.drawPill(p.x, p.y, p.w, p.h, p.c) end
    self.list = {}
end

-- A callout's marker: the tick sitting on the bar at the projected level, plus the leader running up
-- to wherever the pill ended up.
function PoolCallout.drawMark(x, y, w, h, c)
    local col, a = c.color, c.alpha
    local ax, ay = c.anchorX, c.anchorY
    -- The leader attaches at the point nearest the anchor, so a pill clamped to the panel edge still
    -- leans toward the bar level it speaks for rather than pointing off into space.
    local sx = math.max(x + 5, math.min(ax, x + w - 5))

    -- The mark runs THROUGH the bar, not just up to it: the rows are packed tightly, so a caret
    -- resting in the gap above a bar sits as close to the bar overhead as to its own. A tick cutting
    -- the full bar height can only belong to the bar it cuts.
    --
    -- Laid down over a dark halo first, because the tick lands exactly on the boundary of the slice
    -- it marks -- and a PENDING slice is white, the same white the tick would otherwise be. Without
    -- the halo the one mark that matters most disappears into the very thing it points at.
    love.graphics.setColor(0.04, 0.05, 0.08, 0.85 * a)
    love.graphics.setLineWidth(3)
    love.graphics.line(ax, ay - TIP, ax, ay + c.barH)
    love.graphics.setColor(col[1], col[2], col[3], 0.9 * a)
    love.graphics.setLineWidth(1)
    love.graphics.line(ax, ay, ax, ay + c.barH)
    love.graphics.polygon("fill", ax, ay, ax - 4, ay - TIP, ax + 4, ay - TIP)
    love.graphics.line(ax, ay - TIP, sx, y + h)
end

-- The pill itself: the pool's own glyph (the same mark the bar and the cost badges wear) and the
-- projected value, tinted by what the change IS -- white pending, amber lethal, green healing.
function PoolCallout.drawPill(x, y, w, h, c)
    local col, a = c.color, c.alpha
    love.graphics.setColor(0.06, 0.07, 0.10, 0.92 * a)
    love.graphics.rectangle("fill", x, y, w, h, 4, 4)
    love.graphics.setColor(col[1], col[2], col[3], 0.75 * a)
    love.graphics.rectangle("line", x, y, w, h, 4, 4)

    local glyph = Glyphs.RESOURCE[c.key] or Glyphs.manaGem
    glyph(x + PAD_X, y + (h - 10) / 2, ICON_W, 10, col[1], col[2], col[3], a)
    love.graphics.setColor(col[1], col[2], col[3], a)
    love.graphics.print(c.text, x + PAD_X + ICON_W + 3, y + 2)
end

return PoolCallout
