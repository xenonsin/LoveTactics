-- Battle arena renderer + input, driven by a models/arena.lua arena. Like
-- ui/overworld_map.lua it supports mouse + keyboard + gamepad. The whole 8x8 grid
-- fits on screen (no camera); a tile cursor can be moved with any input source.
--
-- Tiles are flavoured by the quest's biome: each arena tile type maps to an overworld
-- tileset type (ground->path, rough->grass, obstacle->rock) so the biome's art/colours
-- carry through. If the tileset art is missing, it falls back to colored rects.
--
-- Turn/movement logic is deferred to the combat system; for now this widget renders
-- the map and units and tracks a cursor, so the three-input scaffolding is in place.
--
--   local map = BattleMap.new(arena, { units = { { x, y, side, name, sprite }, ... } })
--   map:update(dt); map:draw()
--   map:mousemoved(x, y); map:mousepressed(x, y, button)
--   map:keypressed(key); map:gamepadpressed(joystick, button)

local Scale = require("scale")
local Sprite = require("models.sprite")
local Tileset = require("models.tileset")
local Biome = require("models.biome")

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
    self.units = opts.units or {}
    self.font = opts.font or love.graphics.newFont(14)
    self.axisThreshold = opts.axisThreshold or DEFAULTS.axisThreshold
    self.axisActive = false

    self.size = arena.tileSize
    self.originX = math.floor((Scale.WIDTH - arena.cols * self.size) / 2)
    self.originY = math.floor((Scale.HEIGHT - arena.rows * self.size) / 2)

    -- Cursor starts on the first party unit (or the grid centre).
    local first = self.units[1]
    self.cursor = {
        x = (first and first.x) or math.floor(arena.cols / 2),
        y = (first and first.y) or math.floor(arena.rows / 2),
    }

    self.tilesetDef = Tileset.get(Biome.get(arena.biome).tileset)
    self:buildTiles()
    return self
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
    self:drawUnits()
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

function BattleMap:drawUnits()
    local s = self.size
    love.graphics.setFont(self.font)
    for _, u in ipairs(self.units) do
        local wx, wy = self:cellToPixel(u.x, u.y)
        local isParty = u.side == "party"
        if type(u.sprite) == "userdata" then
            love.graphics.setColor(1, 1, 1)
            local sw, sh = u.sprite:getDimensions()
            local scale = math.min((s - 8) / sw, (s - 8) / sh)
            love.graphics.draw(u.sprite, wx + s / 2, wy + s / 2, 0, scale, scale,
                sw / 2, sh / 2)
        else
            -- Token fallback: colored disc with the unit's initial.
            if isParty then love.graphics.setColor(0.35, 0.65, 0.95)
            else love.graphics.setColor(0.90, 0.35, 0.30) end
            love.graphics.circle("fill", wx + s / 2, wy + s / 2, s * 0.32)
            love.graphics.setColor(1, 1, 1)
            love.graphics.printf((u.name or "?"):sub(1, 1), wx, wy + s / 2 - 8, s, "center")
        end
        -- Side ring.
        if isParty then love.graphics.setColor(0.4, 0.7, 1, 0.9)
        else love.graphics.setColor(1, 0.45, 0.4, 0.9) end
        love.graphics.rectangle("line", wx + 2, wy + 2, s - 4, s - 4, 4, 4)
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
-- Input
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

function BattleMap:mousemoved(x, y)
    local cx, cy = self:pixelToCell(x, y)
    if cx >= 1 and cx <= self.arena.cols and cy >= 1 and cy <= self.arena.rows then
        self.cursor.x, self.cursor.y = cx, cy
    end
end

function BattleMap:mousepressed(x, y, button)
    if button ~= 1 then return end
    self:mousemoved(x, y)
end

return BattleMap
