-- Context-sensitive mouse cursor.
--
-- The game hides the OS pointer while the mouse is the active device (see main.lua) and draws
-- one of these glyphs instead, chosen per-frame by the current state's optional `cursorKind()`.
-- The kind names the situation under the pointer -- "move" over a walkable tile, "attack" over a
-- foe you can strike, "hand" over a clickable button, and so on -- so the cursor itself tells the
-- player what a click will do. See the battle mapping in states/battle.lua (cursorKind).
--
--   local Cursor = require("ui.cursor")
--   Cursor.draw("attack", mouseX, mouseY)   -- in the logical 1280x720 space
--
-- Every glyph is drawn from love.graphics primitives (the project ships no image assets), in the
-- same spirit as ui/close_button.lua: polygon/rectangle/circle with inline color literals and no
-- font. Each is authored so its meaningful point -- a pointer's tip, a reticle's centre -- sits at
-- the local origin (0, 0); Cursor.draw translates that origin to the mouse point. Nothing here
-- touches love.graphics until draw time, so the module loads under the headless test suite.

local Cursor = {}

-- A soft near-black used as a 1px drop-shadow / outline behind every glyph so it stays legible
-- over any board tile, panel, or overlay it floats above.
local SHADOW = { 0.05, 0.05, 0.07, 0.9 }

-- Render a shape twice: once shifted by (1.5, 1.5) in the shadow tone, then in `color` in place.
-- `shape` issues the actual (color-agnostic) love.graphics calls, so the same silhouette gets a
-- built-in outline for free. `shape` may push its own transforms; they nest cleanly.
local function outlined(color, shape)
    love.graphics.push()
    love.graphics.translate(1.5, 1.5)
    love.graphics.setColor(SHADOW)
    shape()
    love.graphics.pop()
    love.graphics.setColor(color)
    shape()
end

-- A four-point sparkle (a plus stretched to points) centred at (cx, cy), radius r. Used to mark
-- "magic" on the blink and cast glyphs.
local function sparkle(cx, cy, r)
    local s = r * 0.32
    love.graphics.polygon("fill",
        cx, cy - r, cx + s, cy - s, cx + r, cy, cx + s, cy + s,
        cx, cy + r, cx - s, cy + s, cx - r, cy, cx - s, cy - s)
end

-- ---------------------------------------------------------------------------
-- Glyphs. Each places its anchor point at (0, 0). Sized ~26px so it reads clearly yet doesn't
-- blanket a 60px board tile.
-- ---------------------------------------------------------------------------

local LIGHT = { 0.96, 0.96, 0.98 }

-- Classic arrow pointer: tip at the origin, body down-right. The neutral default.
local function drawArrow()
    outlined(LIGHT, function()
        love.graphics.polygon("fill",
            0, 0,  0, 18,  5, 13,  8.5, 20,  11, 19,  7.5, 12,  13, 12)
    end)
end

-- Pointing hand: an extended index finger (tip at the origin) rising from the LEFT of a rounded
-- fist -- fist and folded fingers sit to the right, the thumb juts left -- so it reads as a pointing
-- hand, not a raised middle finger. Marks anything clickable (buttons, panels, menu items, buildings).
local function drawHand()
    outlined(LIGHT, function()
        love.graphics.rectangle("fill", -2, 0, 4.5, 15, 2, 2)       -- index finger, tip at origin
        love.graphics.rectangle("fill", -2, 11, 15, 12, 4, 4)       -- fist / palm, offset to the right
        love.graphics.rectangle("fill", -5, 14, 4, 7, 2, 2)         -- thumb juts out to the left
        -- Folded-finger knuckles bunched on the right of the fist.
        love.graphics.rectangle("fill", 4, 9, 3.5, 6, 1.5, 1.5)
        love.graphics.rectangle("fill", 8, 10, 3.5, 6, 1.5, 1.5)
    end)
end

-- One side-profile boot, toe pointing right, drawn in its own local frame at horizontal offset ox.
local function boot(ox)
    love.graphics.push()
    love.graphics.translate(ox, 0)
    -- Silhouette: a leg (left) turning into a foot+sole (right), like an L with a toe.
    love.graphics.polygon("fill",
        0, 0,  6, 0,  6, 10,  16, 10,  17, 13,  16, 16,  2, 16,  0, 14)
    love.graphics.pop()
end

-- A pair of boots, for a reachable move tile.
local BOOT = { 0.6, 0.78, 0.98 }
local function drawMove()
    outlined(BOOT, function()
        boot(0)
        boot(9)
    end)
end

-- Boots plus a teleport sparkle, for a blink/teleport move target.
local BLINK = { 0.55, 0.92, 0.97 }
local function drawBlink()
    outlined(BLINK, function()
        boot(0)
        boot(9)
        sparkle(24, 3, 5)
    end)
end

-- A sword, tip at the origin, tilted so it reads as a pointer. For an attackable foe.
local BLADE = { 0.98, 0.55, 0.5 }
local function drawAttack()
    outlined(BLADE, function()
        love.graphics.push()
        love.graphics.rotate(-0.42) -- lean the blade back like an arrow cursor; tip stays at origin
        love.graphics.polygon("fill", 0, 0, 3, 19, -3, 19)          -- blade, point at origin
        love.graphics.rectangle("fill", -8, 18, 16, 3.5, 1, 1)      -- crossguard
        love.graphics.rectangle("fill", -2, 21.5, 4, 7, 1, 1)       -- grip
        love.graphics.circle("fill", 0, 30, 3)                      -- pommel
        love.graphics.pop()
    end)
end

-- A war hammer, tip (head) at the origin, for breaking a revealed trap or a wall ("strikeTrap").
local ORANGE = { 0.98, 0.72, 0.35 }
local function drawBreak()
    outlined(ORANGE, function()
        love.graphics.push()
        love.graphics.rotate(-0.35)
        love.graphics.rectangle("fill", -9, 0, 18, 8, 1.5, 1.5)     -- hammer head, top at origin
        love.graphics.rectangle("fill", -2.5, 8, 5, 20, 1, 1)       -- haft
        love.graphics.pop()
    end)
end

-- A wand with a sparkle at its tip, for an armed offensive ability aimed at a valid target.
local VIOLET = { 0.78, 0.62, 0.98 }
local function drawCast()
    outlined(VIOLET, function()
        love.graphics.setLineWidth(3.5)
        love.graphics.line(3, 3, 17, 20)  -- shaft, tip near the origin
        sparkle(0, 0, 6)                  -- sparkle at the wand tip (the cursor point)
        love.graphics.setLineWidth(1)
    end)
end

-- A bold rounded plus, for a supportive (heal/buff) cast on an ally. Centred on the origin.
local GREEN = { 0.5, 0.92, 0.55 }
local function drawHeal()
    outlined(GREEN, function()
        love.graphics.rectangle("fill", -3.5, -10, 7, 20, 2, 2)  -- vertical bar
        love.graphics.rectangle("fill", -10, -3.5, 20, 7, 2, 2)  -- horizontal bar
    end)
end

-- A reticle, for a tile-placement ability (drop a trap / summon a creature). Centred on the origin,
-- so the crosshair -- not a corner -- sits under the pointer.
local GOLD = { 0.98, 0.86, 0.5 }
local function drawTarget()
    outlined(GOLD, function()
        love.graphics.setLineWidth(2.5)
        love.graphics.circle("line", 0, 0, 9)
        love.graphics.line(-14, 0, -6, 0)   -- four ticks
        love.graphics.line(6, 0, 14, 0)
        love.graphics.line(0, -14, 0, -6)
        love.graphics.line(0, 6, 0, 14)
        love.graphics.setLineWidth(1)
        love.graphics.circle("fill", 0, 0, 1.5)
    end)
end

-- An hourglass, shown over the board while it is not the player's turn (enemy acting, a walk
-- animation, or a channel resolving) -- a click would do nothing, so the cursor says "wait".
local DIM = { 0.72, 0.72, 0.78 }
local function drawWait()
    outlined(DIM, function()
        love.graphics.setLineWidth(2.5)
        love.graphics.line(-7, -10, 7, -10)   -- top cap
        love.graphics.line(-7, 10, 7, 10)     -- bottom cap
        love.graphics.setLineWidth(1)
        love.graphics.polygon("line", -6, -9, 6, -9, 6, 9, -6, 9)  -- glass outline
        love.graphics.polygon("fill", -5, -8, 5, -8, 0, 0)         -- top bulb of "sand"
        love.graphics.polygon("fill", 0, 0, 4, 8, -4, 8)           -- bottom pile
    end)
end

local KINDS = {
    arrow  = drawArrow,
    hand   = drawHand,
    move   = drawMove,
    blink  = drawBlink,
    attack = drawAttack,
    ["break"] = drawBreak,
    cast   = drawCast,
    heal   = drawHeal,
    target = drawTarget,
    wait   = drawWait,
}

-- Draw the glyph for `kind` with its anchor at (x, y). Unknown kinds fall back to the arrow.
function Cursor.draw(kind, x, y)
    local draw = KINDS[kind] or KINDS.arrow
    love.graphics.push()
    love.graphics.translate(x, y)
    draw()
    love.graphics.pop()
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1)  -- leave the graphics state clean, as the widgets expect
end

-- Exposed so a test can assert every mapped kind is drawable.
Cursor.KINDS = KINDS

return Cursor
