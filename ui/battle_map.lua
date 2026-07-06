-- Battle arena renderer + input, driven by a models/arena.lua arena and a live
-- models/combat.lua instance. Like ui/overworld_map.lua it supports mouse + keyboard +
-- gamepad. The whole 8x8 grid fits on screen (no camera); a tile cursor can be moved with
-- any input source, and the owning state (states/battle.lua) interprets confirm presses.
--
-- Tiles are flavoured by the quest's biome: each arena tile type maps to an overworld
-- tileset type (ground->path, rough->grass, obstacle->rock) so the biome's art/colours
-- carry through. If the tileset art is missing, it falls back to colored rects.
--
-- Units are drawn from the combat model (live positions / HP / alive), each with an on-tile
-- HP bar and its turn-order number. The state feeds per-frame overlays (blue reachable move
-- tiles, red ability-range tiles) via setOverlays, and the arena is centred in the space
-- left of the right-side combat panel via opts.rightMargin.
--
--   local map = BattleMap.new(arena, { combat = combat, rightMargin = 320 })
--   map:setOverlays({ move = { {x,y}, ... }, range = { {x,y}, ... } })
--   map:update(dt); map:draw()
--   map:mousemoved(x, y); map:mousepressed(x, y, button)
--   map:keypressed(key); map:gamepadpressed(joystick, button)

local Scale = require("scale")
local Sprite = require("models.sprite")
local Tileset = require("models.tileset")
local Biome = require("models.biome")
local Combat = require("models.combat")

local BattleMap = {}
BattleMap.__index = BattleMap

-- Arena tile type -> overworld tileset type, so each biome's art/colours flavour the
-- arena ground.
local ART = { ground = "path", rough = "grass", obstacle = "rock" }

local DEFAULTS = { axisThreshold = 0.5 }

function BattleMap.new(arena, opts)
    opts = opts or {}
    local self = setmetatable({}, BattleMap)
    self.arena = arena
    self.combat = opts.combat
    self.rightMargin = opts.rightMargin or 0
    self.font = opts.font or love.graphics.newFont(14)
    self.numberFont = opts.numberFont or love.graphics.newFont(12)
    self.axisThreshold = opts.axisThreshold or DEFAULTS.axisThreshold
    self.axisActive = false
    self.overlays = { move = {}, range = {} }

    self.size = arena.tileSize
    -- Centre the board in the space left of the combat panel (rightMargin), not the whole
    -- window, so the panel never covers it.
    self.originX = math.floor((Scale.WIDTH - self.rightMargin - arena.cols * self.size) / 2)
    self.originY = math.floor((Scale.HEIGHT - arena.rows * self.size) / 2)

    -- Cursor starts on the first living party unit (or the grid centre).
    local first = self:firstPartyUnit()
    self.cursor = {
        x = (first and first.x) or math.floor(arena.cols / 2),
        y = (first and first.y) or math.floor(arena.rows / 2),
    }

    self.tilesetDef = Tileset.get(Biome.get(arena.biome).tileset)
    self:buildTiles()
    return self
end

function BattleMap:firstPartyUnit()
    if not self.combat then return nil end
    for _, u in ipairs(self.combat.units) do
        if u.alive and u.side == "party" then return u end
    end
    return nil
end

-- Supply the per-frame highlight sets, each a list of { x, y } cells:
--   move  -> reachable tiles (blue)      range -> armed ability range (red)
function BattleMap:setOverlays(overlays)
    self.overlays = overlays or { move = {}, range = {} }
end

-- Build the tileset quads + SpriteBatch for the mapped art types, or record that we
-- must fall back to colored rects (mirrors OverworldMap:buildTiles).
function BattleMap:buildTiles()
    local tsDef = self.tilesetDef
    local img = Sprite.load(tsDef.image)
    if type(img) ~= "userdata" then
        self.tileset = nil
        return
    end
    self.tileset = img
    local ts = tsDef.tileSize
    local columns = math.max(1, math.floor(img:getWidth() / ts))
    local quads = {}
    for _, artType in pairs(ART) do
        if not quads[artType] then
            local i = tsDef.tiles[artType].index - 1
            quads[artType] = love.graphics.newQuad((i % columns) * ts,
                math.floor(i / columns) * ts, ts, ts, img:getDimensions())
        end
    end
    self.quads = quads
    self.tileScale = self.size / ts
end

function BattleMap:cellToPixel(x, y)
    return self.originX + (x - 1) * self.size, self.originY + (y - 1) * self.size
end

function BattleMap:pixelToCell(px, py)
    return math.floor((px - self.originX) / self.size) + 1,
        math.floor((py - self.originY) / self.size) + 1
end

function BattleMap:update(dt)
    self.time = (self.time or 0) + dt -- drives the current-unit highlight pulse
    -- Poll the analog stick for cursor movement (edge-detected so a held stick moves
    -- one cell per push, matching ui/menu.lua).
    if not love.joystick then return end
    for _, joy in ipairs(love.joystick.getJoysticks()) do
        if joy:isGamepad() then
            local ax, ay = joy:getGamepadAxis("leftx"), joy:getGamepadAxis("lefty")
            local dx, dy = 0, 0
            if ax <= -self.axisThreshold then dx = -1
            elseif ax >= self.axisThreshold then dx = 1
            elseif ay <= -self.axisThreshold then dy = -1
            elseif ay >= self.axisThreshold then dy = 1 end
            if dx == 0 and dy == 0 then
                self.axisActive = false
            elseif not self.axisActive then
                self.axisActive = true
                self:moveCursor(dx, dy)
            end
        end
    end
end

function BattleMap:moveCursor(dx, dy)
    self.cursor.x = math.max(1, math.min(self.arena.cols, self.cursor.x + dx))
    self.cursor.y = math.max(1, math.min(self.arena.rows, self.cursor.y + dy))
end

-- ---------------------------------------------------------------------------
-- Draw
-- ---------------------------------------------------------------------------

function BattleMap:draw()
    self:drawTiles()
    self:drawOverlays()
    self:drawUnits()
    self:drawHighlights()
    self:drawUnitInfo() -- HP bars + turn numbers sit above the highlight fills
    self:drawCursor()
    love.graphics.setColor(1, 1, 1)
end

function BattleMap:drawTiles()
    local s = self.size
    for y = 1, self.arena.rows do
        for x = 1, self.arena.cols do
            local cell = self.arena.tiles[y][x]
            local artType = ART[cell.type] or "path"
            local wx, wy = self:cellToPixel(x, y)
            if self.tileset then
                love.graphics.setColor(1, 1, 1)
                love.graphics.draw(self.tileset, self.quads[artType], wx, wy, 0,
                    self.tileScale, self.tileScale)
            else
                local col = self.tilesetDef.tiles[artType].color
                love.graphics.setColor(col[1], col[2], col[3])
                love.graphics.rectangle("fill", wx, wy, s, s)
            end
            -- Impassable tiles get a darkening overlay so blocked cells read clearly.
            if not cell.walkable then
                love.graphics.setColor(0, 0, 0, 0.45)
                love.graphics.rectangle("fill", wx, wy, s, s)
            elseif cell.type == "rough" then
                love.graphics.setColor(0.2, 0.15, 0.05, 0.25)
                love.graphics.rectangle("fill", wx, wy, s, s)
            end
            -- Grid line.
            love.graphics.setColor(0, 0, 0, 0.25)
            love.graphics.rectangle("line", wx, wy, s, s)
        end
    end
end

-- Translucent highlight fills for reachable move tiles (blue) and armed ability range
-- (red), drawn under the units so tokens stay legible on top.
function BattleMap:drawOverlays()
    local s = self.size
    local function paint(cells, r, g, b)
        for _, c in ipairs(cells or {}) do
            local wx, wy = self:cellToPixel(c.x, c.y)
            love.graphics.setColor(r, g, b, 0.32)
            love.graphics.rectangle("fill", wx + 1, wy + 1, s - 2, s - 2)
            love.graphics.setColor(r, g, b, 0.85)
            love.graphics.rectangle("line", wx + 1, wy + 1, s - 2, s - 2)
        end
    end
    paint(self.overlays.move, 0.30, 0.60, 1.00)
    -- Support abilities (heals / buffs) reach in green; offensive ones in red.
    if self.overlays.rangeSupport then
        paint(self.overlays.range, 0.35, 0.85, 0.40)
    else
        paint(self.overlays.range, 1.00, 0.32, 0.30)
    end
end

-- Unit bodies: sprite/token + side ring. HP bars and turn numbers are a separate pass
-- (drawUnitInfo) drawn AFTER the highlights so those readouts stay legible on top.
function BattleMap:drawUnits()
    if not self.combat then return end
    local s = self.size
    for _, u in ipairs(self.combat.units) do
        if u.alive then
            local wx, wy = self:cellToPixel(u.x, u.y)
            local isParty = u.side == "party"
            local sprite = u.char.sprite
            if type(sprite) == "userdata" then
                love.graphics.setColor(1, 1, 1)
                local sw, sh = sprite:getDimensions()
                local scale = math.min((s - 8) / sw, (s - 8) / sh)
                love.graphics.draw(sprite, wx + s / 2, wy + s / 2, 0, scale, scale,
                    sw / 2, sh / 2)
            else
                -- Token fallback: colored disc with the unit's initial.
                if isParty then love.graphics.setColor(0.35, 0.65, 0.95)
                else love.graphics.setColor(0.90, 0.35, 0.30) end
                love.graphics.circle("fill", wx + s / 2, wy + s / 2, s * 0.32)
                love.graphics.setFont(self.font)
                love.graphics.setColor(1, 1, 1)
                love.graphics.printf((u.char.name or "?"):sub(1, 1), wx, wy + s / 2 - 8, s, "center")
            end
            -- Side ring.
            if isParty then love.graphics.setColor(0.4, 0.7, 1, 0.9)
            else love.graphics.setColor(1, 0.45, 0.4, 0.9) end
            love.graphics.rectangle("line", wx + 2, wy + 2, s - 4, s - 4, 4, 4)
        end
    end
end

-- HP bars + turn-order numbers, drawn last (above highlights) so they're never tinted.
function BattleMap:drawUnitInfo()
    if not self.combat then return end
    local orderIndex = {}
    for i, u in ipairs(Combat.turnOrder(self.combat)) do orderIndex[u] = i end
    for _, u in ipairs(self.combat.units) do
        if u.alive then
            local wx, wy = self:cellToPixel(u.x, u.y)
            self:drawHpBar(u, wx, wy)
            self:drawTurnNumber(orderIndex[u], wx, wy)
        end
    end
end

-- Thin HP bar along the bottom of the unit's tile (green -> red as HP drops).
function BattleMap:drawHpBar(u, wx, wy)
    local s = self.size
    local hp = u.char.stats.health
    local ratio = 0
    if hp and hp.max and hp.max > 0 then ratio = math.max(0, math.min(1, hp.current / hp.max)) end
    local bx, by, bw, bh = wx + 4, wy + s - 8, s - 8, 5
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", bx - 1, by - 1, bw + 2, bh + 2, 2, 2)
    -- Hue: green when full, red when empty.
    love.graphics.setColor(1 - ratio, 0.2 + 0.6 * ratio, 0.15, 0.95)
    love.graphics.rectangle("fill", bx, by, bw * ratio, bh, 2, 2)
end

-- Turn-order number in the tile's top-left, with a dark backing for legibility.
function BattleMap:drawTurnNumber(n, wx, wy)
    if not n then return end
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", wx + 1, wy + 1, 16, 15, 3, 3)
    love.graphics.setFont(self.numberFont)
    love.graphics.setColor(0.98, 0.95, 0.7)
    love.graphics.printf(tostring(n), wx + 1, wy + 1, 16, "center")
end

-- Emphasise the acting unit (pulsing gold ring, always) and the unit the timeline is
-- hovering (steady cyan ring). Colours are distinct so the two never read as the same thing.
function BattleMap:drawHighlights()
    local s = self.size
    local hover = self.overlays.hover
    if hover then
        local wx, wy = self:cellToPixel(hover.x, hover.y)
        love.graphics.setColor(0.75, 0.95, 1.0, 0.16)
        love.graphics.rectangle("fill", wx + 2, wy + 2, s - 4, s - 4, 4, 4)
        love.graphics.setColor(0.75, 0.95, 1.0, 0.95)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", wx + 2, wy + 2, s - 4, s - 4, 4, 4)
        love.graphics.setLineWidth(1)
    end
    local current = self.overlays.current
    if current then
        local wx, wy = self:cellToPixel(current.x, current.y)
        local pulse = 0.65 + 0.35 * math.sin((self.time or 0) * 4)
        love.graphics.setColor(0.98, 0.82, 0.35, 0.13)
        love.graphics.rectangle("fill", wx + 2, wy + 2, s - 4, s - 4, 5, 5)
        love.graphics.setColor(0.98, 0.82, 0.35, pulse)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", wx + 3, wy + 3, s - 6, s - 6, 5, 5)
        love.graphics.setLineWidth(1)
    end
end

function BattleMap:drawCursor()
    local wx, wy = self:cellToPixel(self.cursor.x, self.cursor.y)
    local s = self.size
    love.graphics.setColor(0.98, 0.92, 0.55, 0.95)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", wx + 1, wy + 1, s - 2, s - 2, 4, 4)
    love.graphics.setLineWidth(1)
end

-- ---------------------------------------------------------------------------
-- Input  (cursor movement only; the state interprets confirm presses)
-- ---------------------------------------------------------------------------

function BattleMap:keypressed(key)
    if key == "left" or key == "a" then self:moveCursor(-1, 0)
    elseif key == "right" or key == "d" then self:moveCursor(1, 0)
    elseif key == "up" or key == "w" then self:moveCursor(0, -1)
    elseif key == "down" or key == "s" then self:moveCursor(0, 1) end
end

function BattleMap:gamepadpressed(_, button)
    if button == "dpleft" then self:moveCursor(-1, 0)
    elseif button == "dpright" then self:moveCursor(1, 0)
    elseif button == "dpup" then self:moveCursor(0, -1)
    elseif button == "dpdown" then self:moveCursor(0, 1) end
end

-- Returns true if (x, y) fell on a grid cell (cursor moved), so the state can tell a
-- battlefield click from a click elsewhere.
function BattleMap:mousemoved(x, y)
    local cx, cy = self:pixelToCell(x, y)
    if cx >= 1 and cx <= self.arena.cols and cy >= 1 and cy <= self.arena.rows then
        self.cursor.x, self.cursor.y = cx, cy
        return true
    end
    return false
end

function BattleMap:mousepressed(x, y, button)
    if button ~= 1 then return false end
    return self:mousemoved(x, y)
end

return BattleMap
