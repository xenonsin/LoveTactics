-- Battle arena renderer + input, driven by a models/arena.lua arena and a live
-- models/combat.lua instance. Like ui/overworld_map.lua it supports mouse + keyboard +
-- gamepad. The whole 8x8 grid fits on screen (no camera); a tile cursor can be moved with
-- any input source, and the owning state (states/battle.lua) interprets confirm presses.
--
-- Tiles are flavoured by the quest's biome: each arena tile type maps to an overworld
-- tileset type (ground->path, forest->forest, mountain/obstacle->rock, rough->grass) so the
-- biome's art/colours carry through. If the tileset art is missing, it falls back to colored
-- rects. Costly terrain also gets a translucent wash so its slowness reads at a glance.
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
local Status = require("models.status")
local StatusBadge = require("ui.status_badge")

local BattleMap = {}
BattleMap.__index = BattleMap

-- Arena tile type -> overworld tileset type, so each biome's art/colours flavour the
-- arena ground.
local ART = {
    ground = "path", forest = "forest", mountain = "rock",
    rough = "grass", obstacle = "rock",
}

-- Translucent wash over costly terrain (drawn on walkable tiles) so a tile's move penalty
-- reads at a glance: leafy green for forest, cold grey for mountain, brown for legacy rough.
local TERRAIN_TINT = {
    forest   = { 0.10, 0.35, 0.12, 0.28 },
    mountain = { 0.30, 0.30, 0.34, 0.35 },
    rough    = { 0.20, 0.15, 0.05, 0.25 },
}

local DEFAULTS = { axisThreshold = 0.5 }

function BattleMap.new(arena, opts)
    opts = opts or {}
    local self = setmetatable({}, BattleMap)
    self.arena = arena
    self.combat = opts.combat
    self.rightMargin = opts.rightMargin or 0
    self.leftMargin = opts.leftMargin or 0
    self.font = opts.font or love.graphics.newFont(14)
    self.numberFont = opts.numberFont or love.graphics.newFont(12)
    self.axisThreshold = opts.axisThreshold or DEFAULTS.axisThreshold
    self.axisActive = false
    self.overlays = { move = {}, range = {}, threat = {}, traps = {}, hazards = {} }

    -- On-screen tile size. Defaults to the arena's logical tileSize but can be overridden so the
    -- board renders a little smaller than its data size, opening breathing room around it. All
    -- geometry (cell<->pixel, overlays, units, traps, hit-testing) derives from self.size, so they
    -- scale together.
    self.size = opts.tileSize or arena.tileSize
    -- Centre the board in the space *between* the two side columns (leftMargin, rightMargin),
    -- not the whole window, so neither the panel nor the left tooltip column covers it.
    self.originX = self.leftMargin +
        math.floor((Scale.WIDTH - self.leftMargin - self.rightMargin - arena.cols * self.size) / 2)
    -- Anchor the board's top when a topMargin is given (so shrinking the board frees room BELOW
    -- it for the combat-log strip), otherwise centre it vertically.
    self.originY = opts.topMargin or math.floor((Scale.HEIGHT - arena.rows * self.size) / 2)

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
--   move   -> reachable tiles (blue)          range  -> armed ability range (red/green)
--   aoe    -> an armed AoE ability's blast footprint around the aimed cell (bright red/green)
--   threat -> default-attack reach (red), the band beyond `move` shown during MOVE mode
--   traps  -> runtime trap objects the viewer can see (own + detected), drawn under the units
function BattleMap:setOverlays(overlays)
    self.overlays = overlays or { move = {}, range = {}, threat = {}, traps = {}, hazards = {} }
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

-- The grid cell (x, y) under a pixel, or nil if the pixel is off the board. Lets the battle
-- state drive a hover tooltip (ui/tile_tooltip.lua) for the tile the mouse is over.
function BattleMap:cellAt(px, py)
    local cx, cy = self:pixelToCell(px, py)
    if cx >= 1 and cx <= self.arena.cols and cy >= 1 and cy <= self.arena.rows then
        return cx, cy
    end
    return nil
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
    self:drawHazards() -- area effects wash the ground under the interaction highlights
    self:drawOverlays()
    self:drawTraps() -- revealed traps sit above the ground/overlays, under the units
    self:drawUnits()
    self:drawHighlights()
    self:drawUnitInfo() -- HP bars + turn numbers + status badges sit above the highlight fills
    self:drawCursor()
    love.graphics.setColor(1, 1, 1)
end

-- Hazards (self.overlays.hazards): persistent area effects, one runtime object per covered cell
-- ({ x, y, sprite, def }). Always visible to both sides. Drawn as the hazard's sprite, or a
-- translucent tile wash + border tinted by disposition (fire orange, sanctuary green, rain blue), so
-- the footprint reads as a patch of ground. Sits under traps/units.
function BattleMap:drawHazards()
    local s = self.size
    for _, h in ipairs(self.overlays.hazards or {}) do
        if h.alive then
            local wx, wy = self:cellToPixel(h.x, h.y)
            local disp = h.def and h.def.disposition
            local r, g, b = 0.55, 0.72, 0.95 -- neutral (rain) blue
            if disp == "hostile" then r, g, b = 0.95, 0.45, 0.25 -- fire orange
            elseif disp == "friendly" then r, g, b = 0.40, 0.85, 0.50 end -- sanctuary green
            local sprite = h.sprite
            if type(sprite) == "userdata" then
                love.graphics.setColor(1, 1, 1)
                local sw, sh = sprite:getDimensions()
                local scale = math.min(s / sw, s / sh)
                love.graphics.draw(sprite, wx + s / 2, wy + s / 2, 0, scale, scale, sw / 2, sh / 2)
            else
                love.graphics.setColor(r, g, b, 0.30)
                love.graphics.rectangle("fill", wx + 2, wy + 2, s - 4, s - 4, 4, 4)
                love.graphics.setColor(r, g, b, 0.80)
                love.graphics.setLineWidth(2)
                love.graphics.rectangle("line", wx + 2, wy + 2, s - 4, s - 4, 4, 4)
                love.graphics.setLineWidth(1)
            end
        end
    end
    love.graphics.setColor(1, 1, 1)
end

-- Revealed traps (self.overlays.traps): each a runtime trap { x, y, side, sprite, health,
-- maxHealth }. Drawn as the trap's icon or a hazard-diamond marker (tinted by owner side), with
-- a thin HP bar once it has been damaged. Per-side visibility is decided by the state; this
-- widget only draws what it was handed.
function BattleMap:drawTraps()
    local s = self.size
    for _, t in ipairs(self.overlays.traps or {}) do
        if t.alive then
            local wx, wy = self:cellToPixel(t.x, t.y)
            local cx, cy = wx + s / 2, wy + s / 2
            local r, g, b = 0.90, 0.40, 0.35 -- enemy traps read red...
            if t.side == "party" then r, g, b = 0.40, 0.70, 0.95 end -- ...party traps blue
            local sprite = t.sprite
            if type(sprite) == "userdata" then
                love.graphics.setColor(1, 1, 1)
                local sw, sh = sprite:getDimensions()
                local scale = math.min((s - 16) / sw, (s - 16) / sh)
                love.graphics.draw(sprite, cx, cy, 0, scale, scale, sw / 2, sh / 2)
            else
                local rad = s * 0.22
                love.graphics.setColor(r, g, b, 0.85)
                love.graphics.polygon("fill", cx, cy - rad, cx + rad, cy, cx, cy + rad, cx - rad, cy)
                love.graphics.setColor(0, 0, 0, 0.7)
                love.graphics.setLineWidth(2)
                love.graphics.polygon("line", cx, cy - rad, cx + rad, cy, cx, cy + rad, cx - rad, cy)
                love.graphics.setLineWidth(1)
                love.graphics.setFont(self.numberFont)
                love.graphics.setColor(0.05, 0.05, 0.07)
                love.graphics.printf("!", wx, cy - 8, s, "center")
            end
            -- Damaged trap: a thin amber HP bar along the tile bottom.
            if t.health and t.maxHealth and t.health < t.maxHealth then
                local ratio = math.max(0, math.min(1, t.health / t.maxHealth))
                local bx, by, bw, bh = wx + 8, wy + s - 12, s - 16, 4
                love.graphics.setColor(0, 0, 0, 0.6)
                love.graphics.rectangle("fill", bx - 1, by - 1, bw + 2, bh + 2, 2, 2)
                love.graphics.setColor(0.9, 0.7, 0.3, 0.95)
                love.graphics.rectangle("fill", bx, by, bw * ratio, bh, 2, 2)
            end
        end
    end
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
            -- Impassable tiles get a darkening overlay so blocked cells read clearly;
            -- walkable-but-costly terrain gets its per-type wash.
            if not cell.walkable then
                love.graphics.setColor(0, 0, 0, 0.45)
                love.graphics.rectangle("fill", wx, wy, s, s)
            else
                local tint = TERRAIN_TINT[cell.type]
                if tint then
                    love.graphics.setColor(tint[1], tint[2], tint[3], tint[4])
                    love.graphics.rectangle("fill", wx, wy, s, s)
                end
            end
            -- Grid line.
            love.graphics.setColor(0, 0, 0, 0.25)
            love.graphics.rectangle("line", wx, wy, s, s)
        end
    end
end

-- Highlight sets for reachable move tiles (blue) and armed ability range (red/green), drawn under
-- the units so tokens stay legible on top. Each set is painted as a soft low-alpha wash with a
-- single outline traced around the region's OUTER boundary only -- so a large set reads as one
-- shape instead of a grid of loudly-boxed cells. A dark backing stroke under the coloured edge
-- keeps it legible over same-hue terrain (the red reach over reddish ground).
function BattleMap:drawOverlays()
    local s = self.size
    local function paint(cells, r, g, b)
        cells = cells or {}
        -- Soft fill.
        love.graphics.setColor(r, g, b, 0.26)
        for _, c in ipairs(cells) do
            local wx, wy = self:cellToPixel(c.x, c.y)
            love.graphics.rectangle("fill", wx + 1, wy + 1, s - 2, s - 2)
        end
        -- Collect only the boundary edges: a cell edge is drawn when the neighbour across it is
        -- NOT in the set. Interior edges (between two members) are skipped.
        local inSet = {}
        for _, c in ipairs(cells) do inSet[c.x .. "," .. c.y] = true end
        local segs = {}
        for _, c in ipairs(cells) do
            local wx, wy = self:cellToPixel(c.x, c.y)
            local x1, y1, x2, y2 = wx + 1, wy + 1, wx + s - 1, wy + s - 1
            if not inSet[c.x .. "," .. (c.y - 1)] then segs[#segs + 1] = { x1, y1, x2, y1 } end
            if not inSet[c.x .. "," .. (c.y + 1)] then segs[#segs + 1] = { x1, y2, x2, y2 } end
            if not inSet[(c.x - 1) .. "," .. c.y] then segs[#segs + 1] = { x1, y1, x1, y2 } end
            if not inSet[(c.x + 1) .. "," .. c.y] then segs[#segs + 1] = { x2, y1, x2, y2 } end
        end
        -- Dark backing pass, then the coloured boundary on top.
        love.graphics.setColor(0, 0, 0, 0.40)
        love.graphics.setLineWidth(2.5)
        for _, g2 in ipairs(segs) do love.graphics.line(g2[1], g2[2], g2[3], g2[4]) end
        love.graphics.setColor(r, g, b, 0.85)
        love.graphics.setLineWidth(1.5)
        for _, g2 in ipairs(segs) do love.graphics.line(g2[1], g2[2], g2[3], g2[4]) end
        love.graphics.setLineWidth(1)
    end
    -- Default-attack (threat) reach in red, under the blue move band. Its cells are the tiles
    -- beyond movement the unit could still strike, so it never overlaps the move set.
    paint(self.overlays.threat, 1.00, 0.32, 0.30)
    paint(self.overlays.move, 0.30, 0.60, 1.00)
    -- Support abilities (heals / buffs) reach in green; offensive ones in red.
    if self.overlays.rangeSupport then
        paint(self.overlays.range, 0.35, 0.85, 0.40)
    else
        paint(self.overlays.range, 1.00, 0.32, 0.30)
    end

    -- Area-of-effect footprint: the cells an armed AoE ability would hit if fired at the aimed
    -- cell, drawn OVER (and brighter than) the range wash so the blast reads at a glance -- green
    -- for a friendly area cast, red for a hostile one. Cells can extend past the range set (a blast
    -- that clips tiles you couldn't aim at directly), so it paints its own fill + a bold border.
    if self.overlays.aoe then
        local r, g, b = 1.00, 0.42, 0.30
        if self.overlays.aoeSupport then r, g, b = 0.40, 0.90, 0.45 end
        for _, c in ipairs(self.overlays.aoe) do
            local wx, wy = self:cellToPixel(c.x, c.y)
            love.graphics.setColor(r, g, b, 0.40)
            love.graphics.rectangle("fill", wx + 1, wy + 1, s - 2, s - 2)
            love.graphics.setColor(0, 0, 0, 0.5)
            love.graphics.setLineWidth(3)
            love.graphics.rectangle("line", wx + 2, wy + 2, s - 4, s - 4)
            love.graphics.setColor(r, g, b, 1.0)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", wx + 2, wy + 2, s - 4, s - 4)
        end
        love.graphics.setLineWidth(1)
    end
end

-- Unit bodies: sprite/token + side ring. HP bars and turn numbers are a separate pass
-- (drawUnitInfo) drawn AFTER the highlights so those readouts stay legible on top.
-- An untargetable (Invisible) unit is drawn faded: the player still sees where their own hidden
-- unit stands, and the fade is the cue that the enemy currently cannot reach it.
function BattleMap:drawUnits()
    if not self.combat then return end
    local s = self.size
    for _, u in ipairs(self.combat.units) do
        if u.alive then
            local wx, wy = self:cellToPixel(u.x, u.y)
            local isParty = u.side == "party"
            local a = Status.untargetable(u) and 0.40 or 1
            local sprite = u.char.sprite
            if type(sprite) == "userdata" then
                love.graphics.setColor(1, 1, 1, a)
                local sw, sh = sprite:getDimensions()
                local scale = math.min((s - 8) / sw, (s - 8) / sh)
                love.graphics.draw(sprite, wx + s / 2, wy + s / 2, 0, scale, scale,
                    sw / 2, sh / 2)
            else
                -- Token fallback: colored disc with the unit's initial.
                if isParty then love.graphics.setColor(0.35, 0.65, 0.95, a)
                else love.graphics.setColor(0.90, 0.35, 0.30, a) end
                love.graphics.circle("fill", wx + s / 2, wy + s / 2, s * 0.32)
                love.graphics.setFont(self.font)
                love.graphics.setColor(1, 1, 1, a)
                love.graphics.printf((u.char.name or "?"):sub(1, 1), wx, wy + s / 2 - 8, s, "center")
            end
            -- Side ring.
            if isParty then love.graphics.setColor(0.4, 0.7, 1, 0.9 * a)
            else love.graphics.setColor(1, 0.45, 0.4, 0.9 * a) end
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
            self:drawStatusBadges(u, wx, wy)
        end
    end
end

-- The on-screen rect of each active status badge on unit `u` (whose tile top-left is wx, wy):
-- a right-justified row along the tile's bottom, just above the HP bar. Shared by the badge
-- draw and the hover hit-test (statusAt) so a tooltip lands exactly on the badge pointed at.
function BattleMap:statusBadgeRects(u, wx, wy)
    local list = u.statuses
    if not list or #list == 0 then return {} end
    local s = self.size
    local bw, bh, gap = 18, 12, 2
    local totalW = #list * bw + (#list - 1) * gap
    local startX = wx + s - totalW - 4
    -- The HP bar's black backing tops out at wy + s - 9; sit the badges a couple px above it.
    local by = wy + s - 11 - bh
    local rects = {}
    for i, st in ipairs(list) do
        rects[i] = { st = st, x = startX + (i - 1) * (bw + gap), y = by, w = bw, h = bh }
    end
    return rects
end

-- Active status effects as small badges right-justified along the tile's bottom, sitting just
-- above the HP bar. Each badge shows the status def's `abbr` in its `color`, so a stunned/rooted
-- unit reads at a glance. Reads unit.statuses (runtime data), never love.graphics at require-time.
function BattleMap:drawStatusBadges(u, wx, wy)
    for _, r in ipairs(self:statusBadgeRects(u, wx, wy)) do
        StatusBadge.draw(r.st, r.x, r.y, r.w, r.h)
    end
end

-- The status instance whose badge is under (px, py), or nil. Walks living units' badge rects
-- so the battle state can show a shared tooltip (ui/status_tooltip.lua) for the hovered status.
function BattleMap:statusAt(px, py)
    if not self.combat then return nil end
    for _, u in ipairs(self.combat.units) do
        if u.alive then
            local wx, wy = self:cellToPixel(u.x, u.y)
            for _, r in ipairs(self:statusBadgeRects(u, wx, wy)) do
                if px >= r.x and px <= r.x + r.w and py >= r.y and py <= r.y + r.h then
                    return r.st
                end
            end
        end
    end
    return nil
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

    -- Aimed-action preview: project the hovered cast's damage/heal onto this unit's HP bar so the
    -- incoming hit reads on the board too (mirrors the turn strip's drawResourceBar). No preview =
    -- a plain fill. Hue: green when full, red when empty.
    local pv = self.overlays.hpPreview and self.overlays.hpPreview[u]
    local delta = pv and ((pv.heal or 0) - (pv.damage or 0)) or 0
    if delta ~= 0 and hp and hp.max and hp.max > 0 then
        local afterRatio = math.max(0, math.min(1, (hp.current + delta) / hp.max))
        love.graphics.setColor(1 - ratio, 0.2 + 0.6 * ratio, 0.15, 0.95)
        love.graphics.rectangle("fill", bx, by, bw * math.min(ratio, afterRatio), bh, 2, 2)
        if delta < 0 then -- red slice for the HP about to be lost (brighter on a lethal blow)
            if pv.lethal then love.graphics.setColor(1.0, 0.30, 0.28, 0.9)
            else love.graphics.setColor(0.90, 0.35, 0.30, 0.9) end
            love.graphics.rectangle("fill", bx + bw * afterRatio, by, bw * (ratio - afterRatio), bh, 2, 2)
        else -- green slice for the HP about to be gained
            love.graphics.setColor(0.55, 0.92, 0.58, 0.9)
            love.graphics.rectangle("fill", bx + bw * ratio, by, bw * (afterRatio - ratio), bh, 2, 2)
        end
    else
        love.graphics.setColor(1 - ratio, 0.2 + 0.6 * ratio, 0.15, 0.95)
        love.graphics.rectangle("fill", bx, by, bw * ratio, bh, 2, 2)
    end
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
