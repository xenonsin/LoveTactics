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
local MOVE_INITIAL = 0.18
local MOVE_REPEAT = 0.05

-- Camera easing rate: the camera target snaps to the player each step, but the
-- drawn camera eases toward it (`cam += (target-cam) * min(1, dt*CAM_LERP)`) so
-- the view glides instead of jumping a tile at a time. The player token slides
-- over `MOVE_REPEAT` so it tracks the camera during a continuous walk.
local CAM_LERP = 12

function OverworldMap.new(grid, opts)
    opts = opts or {}
    local self = setmetatable({}, OverworldMap)
    self.grid = grid
    self.onEncounter = opts.onEncounter
    self.font = opts.font or love.graphics.newFont(16)
    self.axisThreshold = opts.axisThreshold or DEFAULTS.axisThreshold
    self.heldDir = nil   -- { dx, dy } of the direction currently held (any input)
    self.moveTimer = 0   -- seconds until the next auto-repeat step
    self.autoPath = nil  -- queued { dx, dy } steps from a mouse click-to-path
    self.autoTimer = 0   -- seconds until the next auto-walk step

    -- Camera easing + token slide state (see CAM_LERP / MOVE_REPEAT). The camera
    -- eases toward camTargetX/Y; the token slides from (slidePrevX, slidePrevY) to
    -- the current tile over slideDur so a hop reads as motion, not a teleport.
    self.slidePrevX, self.slidePrevY = nil, nil
    self.slideT, self.slideDur = 0, MOVE_REPEAT

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
    self:snapCamera()
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

-- Aim the camera at the player, clamped to the map bounds. This only sets the
-- *target*; :update eases the drawn camX/camY toward it so the view glides. Call
-- :snapCamera to jump the drawn camera to the target (e.g. on spawn).
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
    self.camTargetX = clamp(px, mapW, halfW)
    self.camTargetY = clamp(py, mapH, halfH)
    self.camX = self.camX or self.camTargetX
    self.camY = self.camY or self.camTargetY
end

-- Jump the drawn camera straight to its target (no easing) -- used on spawn so the
-- map doesn't pan in from a corner on the first frame.
function OverworldMap:snapCamera()
    self.camX, self.camY = self.camTargetX, self.camTargetY
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
    self.slidePrevX, self.slidePrevY = self.px, self.py -- slide the token from here
    self.slideT = self.slideDur
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

-- Step the token back off the encounter it just triggered, onto the tile it arrived from, WITHOUT
-- re-firing anything -- so a tutorial retry can hand the player back to the overworld one tile shy of
-- the fight, free to open the Loadout and re-equip before stepping onto the (still-uncleared)
-- encounter to try again. `slidePrevX/slidePrevY` is the tile the last :step slid from, which -- since
-- :arrive fires inside that very step -- is exactly the tile just before the encounter. Falls back to
-- leaving the token where it stands (on the encounter) when there is no recorded previous tile, e.g. an
-- encounter reached on spawn. Cancels any in-flight walk and slide so nothing carries the token onward.
function OverworldMap:retreatFromEncounter()
    local bx, by = self.slidePrevX, self.slidePrevY
    if bx and self.grid:isWalkable(bx, by, self.keysHeld) then
        self.px, self.py = bx, by
    end
    self.slidePrevX, self.slidePrevY = nil, nil
    self.slideT = 0
    self.heldDir = nil
    self.autoPath = nil
    self:updateCamera()
    self:snapCamera()
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
    -- Camera easing + token slide run every frame, whether or not we're moving.
    if self.camTargetX then
        local t = math.min(1, dt * CAM_LERP)
        self.camX = self.camX + (self.camTargetX - self.camX) * t
        self.camY = self.camY + (self.camTargetY - self.camY) * t
    end
    if self.slideT > 0 then self.slideT = math.max(0, self.slideT - dt) end

    local dx, dy = self:heldDirection()
    if dx ~= 0 or dy ~= 0 then
        self.autoPath = nil -- manual input cancels any click-to-path walk
        if not self.heldDir or self.heldDir[1] ~= dx or self.heldDir[2] ~= dy then
            self.heldDir = { dx, dy }
            self.moveTimer = MOVE_INITIAL
            self:step(dx, dy)
        else
            self.moveTimer = self.moveTimer - dt
            while self.moveTimer <= 0 do
                self.moveTimer = self.moveTimer + MOVE_REPEAT
                if not self:step(dx, dy) then
                    -- Blocked by a wall or an encounter just opened: end the burst
                    -- and wait the full initial delay before trying to move again.
                    self.moveTimer = MOVE_INITIAL
                    break
                end
            end
        end
        return
    end

    self.heldDir = nil
    self:updateAutoWalk(dt)
end

-- Walk the queued click-to-path (self.autoPath) one tile per MOVE_REPEAT. Stops
-- when the path is spent, a step is blocked, or an encounter opens (step() false).
function OverworldMap:updateAutoWalk(dt)
    if not self.autoPath then return end
    self.autoTimer = self.autoTimer - dt
    while self.autoTimer <= 0 and self.autoPath do
        self.autoTimer = self.autoTimer + MOVE_REPEAT
        local s = table.remove(self.autoPath, 1)
        if not s or not self:step(s[1], s[2]) then
            self.autoPath = nil
        elseif #self.autoPath == 0 then
            self.autoPath = nil
        end
    end
end

-- Fractional cell the token is drawn at: eases (linearly, for smooth chained
-- walking) from the previous tile to the current one across a hop.
function OverworldMap:visualCell()
    if self.slideT > 0 and self.slidePrevX then
        local p = 1 - self.slideT / self.slideDur -- 0 -> 1 across the hop
        return self.slidePrevX + (self.px - self.slidePrevX) * p,
            self.slidePrevY + (self.py - self.slidePrevY) * p
    end
    return self.px, self.py
end

-- The player token's rect in SCREEN space (logical 1280x720), for pinning a coach bubble to it. The
-- map draws under a camera translate of -floor(camX), -floor(camY) (see :draw), so a cell's screen
-- position is its world pixel minus that same floored offset. Uses the eased visual cell so the ring
-- rides with the token as it slides.
function OverworldMap:tokenRect()
    local wx, wy = self.grid:cellToPixel(self:visualCell())
    local s = self.grid.size
    return { x = wx - math.floor(self.camX or 0), y = wy - math.floor(self.camY or 0), w = s, h = s }
end

local function markerColor(kind)
    if kind == "objective" then return 0.95, 0.75, 0.20 end
    if kind == "elite" then return 0.95, 0.55, 0.15 end
    if kind == "town" then return 0.85, 0.85, 0.90 end
    if kind == "treasure" then return 0.35, 0.80, 0.55 end
    if kind == "event" then return 0.60, 0.60, 0.95 end   -- a story stop, not a fight
    if kind == "rest" then return 0.45, 0.80, 0.80 end     -- a safe breather
    return 0.85, 0.25, 0.25 -- combat
end

-- Per-kind marker glyphs, so an encounter reads by its SHAPE and not only its colour -- and no two
-- kinds share the old catch-all "?". Each draws a small vector mark into the box (x, y, w, h) it is
-- handed, the way ui/glyphs.lua does; the caller sets the base colour, and a mark shades its own
-- detail off it. Unknown kinds fall back to the crossed-swords combat mark.
local MarkerIcon = {}

-- Crossed swords: two blades on the diagonal. Ordinary combat.
function MarkerIcon.combat(x, y, w, h, r, g, b, a)
    love.graphics.setColor(r, g, b, a)
    love.graphics.setLineWidth(2)
    love.graphics.line(x, y + h, x + w, y)
    love.graphics.line(x, y, x + w, y + h)
    love.graphics.setLineWidth(1)
end

-- A five-point star: a tougher fight than the rank and file.
function MarkerIcon.elite(x, y, w, h, r, g, b, a)
    love.graphics.setColor(r, g, b, a)
    local cx, cy = x + w / 2, y + h / 2
    local R, ri = w / 2, w / 5
    local pts = {}
    for i = 0, 9 do
        local ang = -math.pi / 2 + i * math.pi / 5
        local rad = (i % 2 == 0) and R or ri
        pts[#pts + 1] = cx + math.cos(ang) * rad
        pts[#pts + 1] = cy + math.sin(ang) * rad
    end
    love.graphics.polygon("fill", pts)
end

-- A planted pennant: the quest's goal.
function MarkerIcon.objective(x, y, w, h, r, g, b, a)
    love.graphics.setColor(r, g, b, a)
    love.graphics.setLineWidth(2)
    love.graphics.line(x + w * 0.22, y, x + w * 0.22, y + h)
    love.graphics.setLineWidth(1)
    love.graphics.polygon("fill", x + w * 0.22, y, x + w, y + h * 0.22, x + w * 0.22, y + h * 0.44)
end

-- A speech bubble: a scene to talk through, not a fight to win.
function MarkerIcon.event(x, y, w, h, r, g, b, a)
    love.graphics.setColor(r, g, b, a)
    love.graphics.rectangle("fill", x, y, w, h * 0.72, 3, 3)
    love.graphics.polygon("fill", x + w * 0.24, y + h * 0.72, x + w * 0.5, y + h * 0.72, x + w * 0.26, y + h)
end

-- A treasure chest: a body under a banded lid, with a dark latch.
function MarkerIcon.treasure(x, y, w, h, r, g, b, a)
    love.graphics.setColor(r, g, b, a)
    love.graphics.rectangle("fill", x, y + h * 0.30, w, h * 0.70, 2, 2)
    love.graphics.rectangle("fill", x, y + h * 0.12, w, h * 0.26, 3, 3)
    love.graphics.setColor(r * 0.4, g * 0.4, b * 0.4, a)
    love.graphics.rectangle("fill", x + w * 0.42, y + h * 0.30, w * 0.16, h * 0.38)
end

-- A tent: a safe camp to rest at.
function MarkerIcon.rest(x, y, w, h, r, g, b, a)
    love.graphics.setColor(r, g, b, a)
    love.graphics.polygon("fill", x + w / 2, y, x, y + h, x + w, y + h)
    love.graphics.setColor(r * 0.35, g * 0.35, b * 0.35, a)
    love.graphics.polygon("fill", x + w / 2, y + h * 0.38, x + w * 0.34, y + h, x + w * 0.66, y + h)
end

-- A house: a roof over a doored body. A friendly town.
function MarkerIcon.town(x, y, w, h, r, g, b, a)
    love.graphics.setColor(r, g, b, a)
    love.graphics.polygon("fill", x + w / 2, y, x, y + h * 0.45, x + w, y + h * 0.45)
    love.graphics.rectangle("fill", x + w * 0.15, y + h * 0.45, w * 0.7, h * 0.55)
    love.graphics.setColor(r * 0.35, g * 0.35, b * 0.35, a)
    love.graphics.rectangle("fill", x + w * 0.4, y + h * 0.6, w * 0.2, h * 0.4)
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
                local kind = c.encounter.kind
                local r, g, b = markerColor(kind)
                local a = c.cleared and 0.3 or 1
                love.graphics.setColor(r, g, b, a)
                love.graphics.rectangle("line", wx + 2, wy + 2, s - 4, s - 4, 4, 4)
                love.graphics.setColor(r, g, b, a * 0.35)
                love.graphics.rectangle("fill", wx + 2, wy + 2, s - 4, s - 4, 4, 4)
                -- Colour still encodes the kind on the box; the icon draws it in white on top so the
                -- SHAPE reads even where two kinds sit close in hue (event violet vs a red combat).
                local icon = MarkerIcon[kind] or MarkerIcon.combat
                local pad = s * 0.28
                icon(wx + pad, wy + pad, s - pad * 2, s - pad * 2, 1, 1, 1, a)
                love.graphics.setColor(1, 1, 1)
            end
        end
    end
end

function OverworldMap:drawPlayer()
    local wx, wy = self.grid:cellToPixel(self:visualCell())
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

-- Mouse-only movement: click any *revealed* tile that's reachable along revealed
-- trail to auto-walk there (an adjacent tile is just the one-step case). Keeps the
-- whole overworld playable with the mouse alone; the walk stops on encounters.
function OverworldMap:mousepressed(x, y, button)
    if button ~= 1 then return end
    local cx, cy = self.grid:pixelToCell(x + self.camX, y + self.camY)
    local path = self:pathTo(cx, cy)
    if path then
        self.autoPath = path
        self.autoTimer = 0 -- take the first step on the next update tick
    end
end

-- BFS from the player to (tx, ty) across tiles that are both revealed (`seen`) and
-- walkable with the keys currently held. Returns a list of { dx, dy } steps, or nil
-- if the target isn't a revealed, reachable trail tile. Backs click-to-path so the
-- mouse never routes the player through fog or a locked gate they can't open.
function OverworldMap:pathTo(tx, ty)
    local grid = self.grid
    local target = grid:get(tx, ty)
    if not target or not target.seen or not grid:isWalkable(tx, ty, self.keysHeld) then
        return nil
    end
    if tx == self.px and ty == self.py then return nil end

    local DIRS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
    local function key(x, y) return y * grid.cols + x end
    local startK = key(self.px, self.py)
    local prev = { [startK] = false } -- visited set; value = { fromKey, dx, dy }
    local q, qi = { { self.px, self.py } }, 1
    while qi <= #q do
        local cur = q[qi]; qi = qi + 1
        if cur[1] == tx and cur[2] == ty then break end
        for _, d in ipairs(DIRS) do
            local nx, ny = cur[1] + d[1], cur[2] + d[2]
            local c = grid:get(nx, ny)
            if c and c.seen and prev[key(nx, ny)] == nil
                and grid:isWalkable(nx, ny, self.keysHeld) then
                prev[key(nx, ny)] = { key(cur[1], cur[2]), d[1], d[2] }
                q[#q + 1] = { nx, ny }
            end
        end
    end

    if prev[key(tx, ty)] == nil then return nil end -- unreachable through revealed trail
    local steps, k = {}, key(tx, ty)
    while k ~= startK do
        local p = prev[k]
        table.insert(steps, 1, { p[2], p[3] })
        k = p[1]
    end
    return steps[1] and steps or nil
end

function OverworldMap:mousemoved(_, _) end

return OverworldMap
