-- Transient "toast" notifications: a small panel that slides in at the top-right, holds for a few
-- seconds, then fades and drops. Driven GLOBALLY by main.lua (updated and drawn on top of
-- everything, even a conversation overlay), so a reward announced mid-scene -- an item handed over
-- by an event choice -- still shows.
--
--   Notification.item(item)                 -- "Received: <item name>", with the item's sprite
--   Notification.push(text, { label = "Received", icon = image, color = {r,g,b} })
--
-- Enqueuing is pure data (no love.graphics), so a model may push one; only :draw touches the GPU,
-- and its fonts are lazy, so the module loads under the headless test runner.

local Scale = require("scale")

local Notification = {}

local queue = {} -- active toasts, oldest first

local LIFE = 3.4   -- seconds fully shown before it begins to leave
local FADE = 0.35  -- fade-in / fade-out time
local MARGIN = 20
local PAD = 12
local ICON = 34
local GAP = 8
local WIDTH = 320

local bodyFont, labelFont
local function fonts()
    bodyFont = bodyFont or love.graphics.newFont(15)
    labelFont = labelFont or love.graphics.newFont(12)
    return bodyFont, labelFont
end

-- Push a toast. `opts.icon` is a loaded love.Image (an item's sprite) drawn at the left; `opts.label`
-- is a small heading above the text ("Received"); `opts.color` tints the accent bar and heading.
function Notification.push(text, opts)
    opts = opts or {}
    queue[#queue + 1] = {
        text = tostring(text or ""),
        label = opts.label,
        icon = type(opts.icon) == "userdata" and opts.icon or nil,
        color = opts.color or { 0.55, 0.85, 0.55 },
        t = 0,
    }
end

-- The commonest case: an item just landed in the stash. Wired to Player.grantItem in main.lua so
-- every reward path (a chest, a quest, an event choice) announces itself through one hook.
function Notification.item(item)
    if not item then return end
    Notification.push(item.name or "Item", {
        label = "Received",
        icon = type(item.sprite) == "userdata" and item.sprite or nil,
        color = { 0.72, 0.86, 0.55 },
    })
end

function Notification.clear()
    for i = #queue, 1, -1 do queue[i] = nil end
end

function Notification.update(dt)
    for i = #queue, 1, -1 do
        local n = queue[i]
        n.t = n.t + dt
        if n.t >= LIFE + FADE * 2 then table.remove(queue, i) end
    end
end

function Notification.draw()
    if #queue == 0 then return end
    local f, lf = fonts()
    local x = Scale.WIDTH - MARGIN - WIDTH
    local y = MARGIN
    for _, n in ipairs(queue) do
        -- Alpha: fade in over FADE, hold for LIFE, fade out over FADE.
        local a = 1
        if n.t < FADE then a = n.t / FADE
        elseif n.t > LIFE + FADE then a = 1 - (n.t - LIFE - FADE) / FADE end
        a = math.max(0, math.min(1, a))
        local slide = (1 - a) * 16 -- slip in from the right as it fades

        local textW = WIDTH - PAD * 2 - (n.icon and (ICON + GAP) or 0)
        local _, lines = f:getWrap(n.text, textW)
        local textH = (n.label and lf:getHeight() + 2 or 0) + math.max(1, #lines) * f:getHeight()
        local h = math.max(textH, n.icon and ICON or 0) + PAD * 2
        local bx = x + slide

        love.graphics.setColor(0.09, 0.10, 0.14, 0.94 * a)
        love.graphics.rectangle("fill", bx, y, WIDTH, h, 8, 8)
        love.graphics.setColor(n.color[1], n.color[2], n.color[3], 0.4 * a)
        love.graphics.rectangle("line", bx, y, WIDTH, h, 8, 8)
        love.graphics.setColor(n.color[1], n.color[2], n.color[3], 0.9 * a)
        love.graphics.rectangle("fill", bx, y, 4, h, 8, 8) -- accent bar down the left edge

        local tx = bx + PAD
        if n.icon then
            love.graphics.setColor(1, 1, 1, a)
            local iw, ih = n.icon:getDimensions()
            local sc = math.min(ICON / iw, ICON / ih)
            love.graphics.draw(n.icon, tx + ICON / 2, y + h / 2, 0, sc, sc, iw / 2, ih / 2)
            tx = tx + ICON + GAP
        end
        local ty = y + PAD
        if n.label then
            love.graphics.setFont(lf)
            love.graphics.setColor(n.color[1], n.color[2], n.color[3], a)
            love.graphics.print(string.upper(n.label), tx, ty)
            ty = ty + lf:getHeight() + 2
        end
        love.graphics.setFont(f)
        love.graphics.setColor(0.92, 0.93, 0.97, a)
        love.graphics.printf(n.text, tx, ty, textW, "left")

        y = y + h + GAP
    end
    love.graphics.setColor(1, 1, 1)
end

return Notification
