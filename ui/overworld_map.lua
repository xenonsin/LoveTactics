-- Scrolling overworld renderer + input, driven by a models/overworld.lua grid.
-- Like ui/building_map.lua it supports mouse + keyboard + gamepad; the input moves
-- a player token along the trail network (hold a direction to keep walking; single
-- taps move one tile) and the camera follows. Stepping onto an encounter tile fires
-- opts.onEncounter(cell); keys are picked up automatically and unlock their gate.
--
-- Tiles are drawn from a tileset spritesheet (quads + SpriteBatch). If the art is
-- missing (Sprite.load returned a path string), it falls back to colored rects per
-- tile type, so the map is playable before art exists.
--
--   local map = OverworldMap.new(grid, { onEncounter = function(cell) ... end })
--   map:update(dt); map:draw()
--   map:mousemoved(x, y); map:mousepressed(x, y, button)
--   map:keypressed(key); map:gamepadpressed(joystick, button)

local Scale = require("scale")
local Sprite = require("models.sprite")
local Tileset = require("models.tileset")

local OverworldMap = {}
OverworldMap.__index = OverworldMap

local DEFAULTS = { axisThreshold = 0.5 }

-- Hold-to-move: after the first step, wait `MOVE_INITIAL` before auto-repeating,
-- then step every `MOVE_REPEAT` seconds while the direction stays held. The pause
-- keeps single taps to one tile; the fast repeat makes long trails quick to walk.
local MOVE_INITIAL = 0.28
local MOVE_REPEAT = 0.08

function OverworldMap.new(grid, opts)
    opts = opts or {}
    local self = setmetatable({}, OverworldMap)
    self.grid = grid
    self.onEncounter = opts.onEncounter
    self.font = opts.font or love.graphics.newFont(16)
    self.axisThreshold = opts.axisThreshold or DEFAULTS.axisThreshold
    self.heldDir = nil   -- { dx, dy } of the direction currently held (any input)
    self.moveTimer = 0   -- seconds until the next auto-repeat step

    -- Fog-of-war vision radius (tiles seen around the player). Defaults to 2; the
    -- game state passes the party's effective radius (raised by a torch, etc.).
    self.visionRadius = opts.visionRadius or 2

    local start = grid:startCell()
    self.px, self.py = start.x, start.y
    self.keysHeld = {} -- keyId -> true

    -- The tileset (sheet + fallback colours) is chosen by the grid's biome.
    self.tilesetDef = Tileset.get(grid.tilesetId)

    self:buildTiles()
    self.grid:reveal(self.px, self.py, self.visionRadius) -- discover the spawn area
    self:updateCamera()
    return self
end

-- Build the tileset quads + SpriteBatch, or record that we must fall back to rects.
function OverworldMap:buildTiles()
    local tsDef = self.tilesetDef
    local img = Sprite.load(tsDef.image)
    if type(img) ~= "userdata" then
        self.tileset = nil -- colored-rect fallback
        return
    end
    self.tileset = img
    local ts = tsDef.tileSize
    local columns = math.max(1, math.floor(img:getWidth() / ts))
    local quads = {}
    for tile, def in pairs(tsDef.tiles) do
        local i = def.index - 1
        quads[tile] = love.graphics.newQuad((i % columns) * ts, math.floor(i / columns) * ts,
            ts, ts, img:getDimensions())
    end
    self.quads = quads
    self.tileScale = self.grid.size / ts

    self.batch = love.graphics.newSpriteBatch(img, self.grid.cols * self.grid.rows)
    for y = 1, self.grid.rows do
        for x = 1, self.grid.cols do
            local c = self.grid:get(x, y)
            local q = quads[c.tile]
            if q then
                local wx, wy = self.grid:cellToPixel(x, y)
                self.batch:add(q, wx, wy, 0, self.tileScale, self.tileScale)
            end
        end
    end
end

-- Centre the camera on the player, clamped to the map bounds.
function OverworldMap:updateCamera()
    local mapW = self.grid.cols * self.grid.size
    local mapH = self.grid.rows * self.grid.size
    local halfW, halfH = Scale.WIDTH / 2, Scale.HEIGHT / 2
    local px, py = self.grid:cellToPixel(self.px, self.py)
    px, py = px + self.grid.size / 2, py + self.grid.size / 2

    local function clamp(v, mapSize, half)
        if mapSize <= half * 2 then return (mapSize - half * 2) / 2 end -- centre small maps
        return math.max(0, math.min(v - half, mapSize - half * 2))
    end
    self.camX = clamp(px, mapW, halfW)
    self.camY = clamp(py, mapH, halfH)
end

-- ---------------------------------------------------------------------------
-- Movement
-- ---------------------------------------------------------------------------

-- Move one tile if the target is walkable. Returns true when the step landed and
-- movement may continue, false when blocked (wall/gate) or when arriving opened an
-- encounter panel -- so a held direction stops instead of walking through it.
function OverworldMap:step(dx, dy)
    local nx, ny = self.px + dx, self.py + dy
    if not self.grid:isWalkable(nx, ny, self.keysHeld) then return false end
    self.px, self.py = nx, ny
    self.grid:reveal(self.px, self.py, self.visionRadius) -- lift the fog around the new tile
    self:updateCamera()
    return not self:arrive()
end

-- React to landing on a tile: pick up keys, trigger encounters. Returns true when
-- it opened an encounter panel, so the caller can halt any in-progress hold-to-move.
function OverworldMap:arrive()
    local c = self.grid:get(self.px, self.py)
    if c.key and not self.keysHeld[c.key.keyId] then
        self.keysHeld[c.key.keyId] = true
        c.picked = true
    end
    if c.encounter and not c.cleared and self.onEncounter then
        self.onEncounter(c)
        return true
    end
    return false
end

-- ---------------------------------------------------------------------------
-- Update / draw
-- ---------------------------------------------------------------------------

-- The single-axis direction currently held on any input source -- keyboard,
-- gamepad d-pad, or the left analog stick -- resolved to one axis (no diagonals on
-- the 4-neighbour grid; horizontal wins). Returns 0, 0 when nothing is held.
function OverworldMap:heldDirection()
    if love.keyboard and love.keyboard.isDown then
        if love.keyboard.isDown("left", "a") then return -1, 0
        elseif love.keyboard.isDown("right", "d") then return 1, 0
        elseif love.keyboard.isDown("up", "w") then return 0, -1
        elseif love.keyboard.isDown("down", "s") then return 0, 1 end
    end
    if love.joystick then
        for _, joy in ipairs(love.joystick.getJoysticks()) do
            if joy:isGamepad() then
                if joy:isGamepadDown("dpleft") then return -1, 0
                elseif joy:isGamepadDown("dpright") then return 1, 0
                elseif joy:isGamepadDown("dpup") then return 0, -1
                elseif joy:isGamepadDown("dpdown") then return 0, 1 end
                local ax, ay = joy:getGamepadAxis("leftx"), joy:getGamepadAxis("lefty")
                if ax <= -self.axisThreshold then return -1, 0
                elseif ax >= self.axisThreshold then return 1, 0
                elseif ay <= -self.axisThreshold then return 0, -1
                elseif ay >= self.axisThreshold then return 0, 1 end
            end
        end
    end
    return 0, 0
end

-- Hold a direction (keyboard, d-pad, or stick) to keep moving: the first frame it
-- is held steps immediately, then it auto-repeats after MOVE_INITIAL, MOVE_REPEAT
-- apart. Changing direction re-arms the pause so a quick tap is a single tile.
function OverworldMap:update(dt)
    local dx, dy = self:heldDirection()
    if dx == 0 and dy == 0 then
        self.heldDir = nil
        return
    end
    if not self.heldDir or self.heldDir[1] ~= dx or self.heldDir[2] ~= dy then
        self.heldDir = { dx, dy }
        self.moveTimer = MOVE_INITIAL
        self:step(dx, dy)
    else
        self.moveTimer = self.moveTimer - dt
        while self.moveTimer <= 0 do
            self.moveTimer = self.moveTimer + MOVE_REPEAT
            if not self:step(dx, dy) then
                -- Blocked by a wall or an encounter just opened: end the burst and
                -- wait the full initial delay before trying to move again.
                self.moveTimer = MOVE_INITIAL
                break
            end
        end
    end
end

local function markerColor(kind)
    if kind == "objective" then return 0.95, 0.75, 0.20 end
    if kind == "elite" then return 0.95, 0.55, 0.15 end
    if kind == "town" then return 0.85, 0.85, 0.90 end
    if kind == "treasure" then return 0.35, 0.80, 0.55 end
    return 0.85, 0.25, 0.25 -- combat
end

function OverworldMap:draw()
    love.graphics.push()
    love.graphics.translate(-math.floor(self.camX), -math.floor(self.camY))

    -- Tiles.
    if self.tileset then
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(self.batch)
    else
        for y = 1, self.grid.rows do
            for x = 1, self.grid.cols do
                local c = self.grid:get(x, y)
                local def = self.tilesetDef.tiles[c.tile]
                local col = def and def.color or { 0.05, 0.05, 0.06 }
                local wx, wy = self.grid:cellToPixel(x, y)
                love.graphics.setColor(col[1], col[2], col[3])
                love.graphics.rectangle("fill", wx, wy, self.grid.size, self.grid.size)
            end
        end
    end

    self:drawMarkers()
    self:drawFog() -- covers undiscovered tiles + their markers; player stays on top
    self:drawPlayer()

    love.graphics.pop()
end

-- Fog of war overlay (drawn after markers so it hides markers on hidden tiles).
-- Three tiers: undiscovered tiles are near-opaque black; discovered tiles outside
-- the current (circular) vision radius are dimmed; tiles within vision are left
-- untouched. Uses the grid's shared inVision test so it matches what reveal lit.
function OverworldMap:drawFog()
    local s = self.grid.size
    local r = self.visionRadius
    for y = 1, self.grid.rows do
        for x = 1, self.grid.cols do
            local c = self.grid:get(x, y)
            local wx, wy = self.grid:cellToPixel(x, y)
            if not c.seen then
                love.graphics.setColor(0.02, 0.02, 0.03, 0.98)
                love.graphics.rectangle("fill", wx, wy, s, s)
            elseif not self.grid:inVision(self.px, self.py, x, y, r) then
                love.graphics.setColor(0.02, 0.02, 0.03, 0.5)
                love.graphics.rectangle("fill", wx, wy, s, s)
            end
        end
    end
    love.graphics.setColor(1, 1, 1)
end

function OverworldMap:drawMarkers()
    local s = self.grid.size
    love.graphics.setFont(self.font)
    for y = 1, self.grid.rows do
        for x = 1, self.grid.cols do
            local c = self.grid:get(x, y)
            local wx, wy = self.grid:cellToPixel(x, y)

            if c.gate then
                -- Locked gate marker: greyed if still locked, faded once opened.
                local held = self.keysHeld[c.gate.keyId]
                love.graphics.setColor(held and 0.45 or 0.75, held and 0.45 or 0.65, 0.25,
                    held and 0.4 or 1)
                love.graphics.rectangle("line", wx + 3, wy + 3, s - 6, s - 6, 4, 4)
                love.graphics.printf(held and "" or "L", wx, wy + s / 2 - 8, s, "center")
            end

            if c.key and not c.picked then
                love.graphics.setColor(0.95, 0.85, 0.35)
                love.graphics.printf("K", wx, wy + s / 2 - 8, s, "center")
            end

            if c.encounter then
                local r, g, b = markerColor(c.encounter.kind)
                local a = c.cleared and 0.3 or 1
                love.graphics.setColor(r, g, b, a)
                love.graphics.rectangle("line", wx + 2, wy + 2, s - 4, s - 4, 4, 4)
                love.graphics.setColor(r, g, b, a * 0.35)
                love.graphics.rectangle("fill", wx + 2, wy + 2, s - 4, s - 4, 4, 4)
                local label = c.encounter.kind == "objective" and "!" or "?"
                love.graphics.setColor(1, 1, 1, a)
                love.graphics.printf(label, wx, wy + s / 2 - 8, s, "center")
            end
        end
    end
end

function OverworldMap:drawPlayer()
    local wx, wy = self.grid:cellToPixel(self.px, self.py)
    local s = self.grid.size
    love.graphics.setColor(0.95, 0.85, 0.55)
    love.graphics.rectangle("line", wx + 1, wy + 1, s - 2, s - 2, 4, 4)
    love.graphics.setColor(0.95, 0.90, 0.70)
    love.graphics.circle("fill", wx + s / 2, wy + s / 2, s * 0.28)
    love.graphics.setColor(1, 1, 1)
end

-- ---------------------------------------------------------------------------
-- Input
-- ---------------------------------------------------------------------------

-- Movement for the keyboard, gamepad d-pad, and analog stick is all polled in
-- :update (hold-to-move), so the discrete press events are intentionally no-ops
-- here; stepping again would double-move and fight the auto-repeat.
function OverworldMap:keypressed(_) end

function OverworldMap:gamepadpressed(_, _) end

-- Mouse-only movement: click an orthogonally adjacent walkable tile to step onto
-- it (keeps the whole overworld playable with the mouse alone).
function OverworldMap:mousepressed(x, y, button)
    if button ~= 1 then return end
    local cx, cy = self.grid:pixelToCell(x + self.camX, y + self.camY)
    local dx, dy = cx - self.px, cy - self.py
    if math.abs(dx) + math.abs(dy) == 1 then
        self:step(dx, dy)
    end
end

function OverworldMap:mousemoved(_, _) end

return OverworldMap
