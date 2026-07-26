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
local Colors = require("ui.colors")
local FieldFx = require("ui.field_fx")
local BurstFx = require("ui.burst_fx")
local Glyphs = require("ui.glyphs")
local SpriteShader = require("shaders.sprite")

-- The two boundary colours for the sprite dissolve/materialize (shaders/sprite.lua): a warm ember eats
-- a felled body, a cold arcane light knits a summoned one into being.
local DISSOLVE_EDGE = { 1.00, 0.55, 0.16 }
local MATERIALIZE_EDGE = { 0.55, 0.74, 1.00 }
local MATERIALIZE_TIME = 0.45 -- seconds a newly-arrived unit spends knitting in

local BattleMap = {}
BattleMap.__index = BattleMap

-- Arena tile type -> overworld tileset type, so each biome's art/colours flavour the
-- arena ground.
local ART = {
    ground = "path", forest = "forest", mountain = "rock",
    rough = "grass", obstacle = "rock", water = "water",
}

-- Translucent wash over costly terrain (drawn on walkable tiles) so a tile's move penalty
-- reads at a glance: leafy green for forest, cold grey for mountain, brown for legacy rough,
-- river blue for the shallows a bolt would carry through (see Combat.tileHasTag).
local TERRAIN_TINT = {
    forest   = { 0.10, 0.35, 0.12, 0.28 },
    mountain = { 0.30, 0.30, 0.34, 0.35 },
    rough    = { 0.20, 0.15, 0.05, 0.25 },
    water    = { 0.12, 0.34, 0.58, 0.34 },
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
    self.overlays = { move = {}, range = {}, threat = {}, traps = {}, hazards = {}, walls = {}, props = {}, charges = {} }

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
    -- The shader-driven ground: hazards, the auras they hold open, the statuses units carry, and the
    -- telegraphs an armed ability paints. Compiles nothing until the first draw (see ui/field_fx.lua).
    self.fields = FieldFx.new()
    -- The point effects: impact bursts, spell blooms and the bolts that fly to them. Shared into the
    -- combat controller by states/battle.lua (which sets fx.bursts to this) so a resolving blow can
    -- spawn its own picture. Compiles nothing until the first burst is drawn (see ui/burst_fx.lua).
    self.bursts = BurstFx.new()
    -- Sprite-transform bookkeeping (shaders/sprite.lua). `materialize` maps a just-arrived unit to the
    -- seconds left on its knit-in; `known` is every unit we have already drawn once, so the units
    -- present at the opening bell are NOT treated as summoned. Compiled lazily on first use.
    self.materialize = {}
    self.known = nil -- nil until the first update seeds it with the starting roster
    return self
end

-- The unit-sprite shader, compiled once on first use and latched on failure -- the board falls back to
-- the flat fade/tint the way ui/field_fx.lua falls back to its wash. Mirrors that guard exactly.
function BattleMap:spriteFx()
    if self.spriteShaderObj then return self.spriteShaderObj end
    if self.spriteShaderFailed then return nil end
    local ok, sh = pcall(love.graphics.newShader, SpriteShader.source)
    if not ok or not sh then
        self.spriteShaderFailed = true
        return nil
    end
    self.spriteShaderObj = sh
    return sh
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
--   logSubjects -> { x, y, unit } marks for the units the hovered combat-log line is about (white)
function BattleMap:setOverlays(overlays)
    self.overlays = overlays or { move = {}, range = {}, threat = {}, traps = {}, hazards = {}, walls = {}, props = {}, charges = {} }
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
    self.fields:update(dt) -- the field shader's shared clock + per-field birth ramps
    self.bursts:update(dt) -- impact bursts age out; bolts in flight advance and land
    self:trackArrivals(dt)  -- a unit that appears mid-battle (a summon, a reinforcement) knits in
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

-- Detect units that were NOT on the board a moment ago and start each one materializing -- a summoner's
-- conjured wolf, a wave of reinforcements walking on. The roster present at the first update is seeded
-- as already-known so nobody knits in at the opening bell; after that any fresh, living unit does. Runs
-- off the combat unit list alone, so it needs no cue from the model -- a summon appears in that list the
-- instant it is placed. Timers tick down here; ui/battle_map.lua's drawUnits reads them.
-- A unit the model has placed but states/battle.lua is still holding off the board -- a body summoned
-- by a cast whose approach walk is replaying (overlays.heldUnits). It must not be drawn, and must not
-- be marked "known" or start materializing, until the cast that conjures it plays: revealed then, it
-- knits in WITH the blow rather than popping onto the field while the summoner is still walking in.
function BattleMap:heldUnit(u)
    local held = self.overlays and self.overlays.heldUnits
    return (held and held[u]) or false
end

function BattleMap:trackArrivals(dt)
    if not self.combat then return end
    if not self.known then
        self.known = {}
        for _, u in ipairs(self.combat.units) do self.known[u] = true end
        return
    end
    for _, u in ipairs(self.combat.units) do
        -- A held summon is left untracked, so its knit-in begins the frame it is revealed, not now.
        if u.alive and not self.known[u] and not self:heldUnit(u) then
            self.known[u] = true
            if self:spriteFx() then self.materialize[u] = MATERIALIZE_TIME end
        end
    end
    for u, t in pairs(self.materialize) do
        t = t - dt
        if t <= 0 then self.materialize[u] = nil else self.materialize[u] = t end
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
    self:drawObjective() -- the ground a reach/hold objective is won on, under everything else
    self:drawFields() -- hazards, auras and carried statuses wash the ground under the highlights
    self:drawOverlays()
    self:drawMovePath() -- the actor's steered walk route, an arrow over the blue move wash
    self:drawWalls() -- conjured blockers stand on the ground, above overlays, under the units
    self:drawProps() -- scattered furniture (barrels, crates) stands beside the walls
    self:drawTraps() -- revealed traps sit above the ground/overlays, under the units
    self:drawCharges() -- buried fuses the viewer can see, with their countdown, beside the traps
    self:drawReinforcements() -- where the next enemy muster lands + its countdown, above overlays, under units
    self:drawUnits()
    self:drawHighlights()
    self.bursts:draw(self) -- impacts, blooms and bolts, over the bodies and highlights, under the readouts
    self:drawUnitInfo() -- HP bars + turn numbers + status badges sit above the highlight fills
    self:drawCursor()
    love.graphics.setColor(1, 1, 1)
end

-- Where the next enemy muster walks on, and the count of ticks until it does. Fed by
-- states/battle.lua's overlays.reinforcements (the committed-but-not-yet-landed waves). Deliberately
-- NOT the field shader the hazards use -- a solid outline, an inward arrow and a per-tile countdown, so
-- a landing zone never reads as dangerous GROUND. The readout lives INSIDE each tile, opposite the
-- arrival arrow, so it neither collides with the arrow nor reaches into a neighbouring tile. Standing a
-- body on a marked tile turns that arrival back (states/battle.lua fireWave), so this is an invitation
-- to act, not just a warning.
local MUSTER = { 0.88, 0.24, 0.18 } -- a saturated muster red, apart from the orange of a hostile field

function BattleMap:drawReinforcements()
    local waves = self.overlays.reinforcements
    if not waves then return end
    -- Flatten to per-cell markers and let the SOONEST arrival own a contested cell: two waves whose
    -- lead windows overlap can commit to the same tile, and one readout per tile is the honest picture
    -- (the earlier wave lands there first; the later one is turned back by that very body).
    local order = {}
    for _, wave in ipairs(waves) do
        for _, tile in ipairs(wave.tiles) do
            order[#order + 1] = { tile = tile, edge = wave.edge, ticks = wave.ticksUntil or 0 }
        end
    end
    table.sort(order, function(a, b) return a.ticks < b.ticks end)

    local s = self.size
    local pulse = 0.5 + 0.5 * math.sin(love.timer.getTime() * 4)
    local font = self.numberFont
    local seen = {}
    for _, m in ipairs(order) do
        local key = m.tile.x .. "," .. m.tile.y
        if not seen[key] then
            seen[key] = true
            local wx, wy = self:cellToPixel(m.tile.x, m.tile.y)
            local tw, th = (m.tile.w or 1) * s, (m.tile.h or 1) * s
            -- Fill + outline, inset 3px so nothing ever touches -- let alone overlaps -- a neighbour tile.
            love.graphics.setColor(MUSTER[1], MUSTER[2], MUSTER[3], 0.12 + 0.10 * pulse)
            love.graphics.rectangle("fill", wx + 3, wy + 3, tw - 6, th - 6, 4, 4)
            love.graphics.setColor(MUSTER[1], MUSTER[2], MUSTER[3], 0.55 + 0.35 * pulse)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", wx + 3, wy + 3, tw - 6, th - 6, 4, 4)
            love.graphics.setLineWidth(1)
            self:drawMusterArrow(wx, wy, tw, th, m.edge, 0.6 + 0.4 * pulse)
            -- The numeric countdown is whole ticks (ceil, so it reads 5..1 and hits 0 at arrival). The
            -- whole telegraph only surfaces once the muster is one turn out -- states/battle.lua gates the
            -- overlay to <= TICKS_PER_TURN ticks -- so WHERE and WHEN land together, and the board never
            -- carries a long, distant clock.
            self:drawMusterCount(wx, wy, tw, th, m.edge, tostring(math.ceil(m.ticks)), font)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- A filled triangle hard against the arrival edge of a tile, pointing INWARD, so the side the muster
-- marches in from reads at a glance.
function BattleMap:drawMusterArrow(wx, wy, tw, th, edge, alpha)
    love.graphics.setColor(MUSTER[1], MUSTER[2], MUSTER[3], alpha)
    local cx, cy = wx + tw / 2, wy + th / 2
    local a = math.min(tw, th) * 0.18
    local m = 7
    local p
    if edge == "bottom" then
        p = { cx, wy + th - m - a * 1.5, cx - a, wy + th - m, cx + a, wy + th - m }
    elseif edge == "left" then
        p = { wx + m + a * 1.5, cy, wx + m, cy - a, wx + m, cy + a }
    elseif edge == "right" then
        p = { wx + tw - m - a * 1.5, cy, wx + tw - m, cy - a, wx + tw - m, cy + a }
    else -- top, and the default "back" muster reading top-of-board
        p = { cx, wy + m + a * 1.5, cx - a, wy + m, cx + a, wy + m }
    end
    love.graphics.polygon("fill", p)
end

-- The tick countdown for ONE landing tile, drawn INSIDE it: an hourglass + ticks-until on a small dark
-- backing, held to the side of the tile OPPOSITE the arrival arrow and clamped to the tile's interior,
-- so it collides with neither the arrow nor a neighbour. Every tile of a wave shows the same count --
-- the number of marked tiles is itself the incoming body count, so it needs no separate tally. (No text
-- ever leaves the tile: the backing width is capped at the tile's inset interior.)
function BattleMap:drawMusterCount(wx, wy, tw, th, edge, ticks, font)
    local gh = math.min(13, th * 0.26)
    local gw = gh * 0.66
    local rowH = math.max(gh, font:getHeight())
    local padX, padY = 4, 2
    local bw = math.min(gw + 3 + font:getWidth(ticks) + padX * 2, tw - 8)
    local bh = rowH + padY * 2
    -- Opposite the arrow: a top/back muster's arrow hugs the top, so the count sits low; a left arrow
    -- hugs the left, so the count sits right; and so on. Keeps a fixed gap between the two marks.
    local bx, by
    if edge == "left" then
        bx, by = wx + tw - bw - 6, wy + (th - bh) / 2
    elseif edge == "right" then
        bx, by = wx + 6, wy + (th - bh) / 2
    elseif edge == "bottom" then
        bx, by = wx + (tw - bw) / 2, wy + 6
    else -- top / back
        bx, by = wx + (tw - bw) / 2, wy + th - bh - 6
    end

    love.graphics.setColor(0.06, 0.05, 0.07, 0.72)
    love.graphics.rectangle("fill", bx, by, bw, bh, 4, 4)
    Glyphs.hourglass(bx + padX, by + (bh - gh) / 2, gw, gh, MUSTER[1], MUSTER[2], MUSTER[3], 0.95)
    love.graphics.setFont(font)
    love.graphics.setColor(0.97, 0.95, 0.91, 1)
    love.graphics.print(ticks, bx + padX + gw + 3, by + (bh - font:getHeight()) / 2)
end

-- Objective ground (self.overlays.objective): the tiles a `reach` or `hold` objective is won on,
-- resolved per board by Arena.resolveRegion. Drawn UNDER the hazards and interaction highlights --
-- it is a property of the terrain, not a thing the current action is doing, and it must never
-- outshout the move/range wash a player is actually steering by.
--
-- `self.overlays.objectiveHeld` is the live control read for a `hold` (nil for `reach`): amber while
-- the ground is contested or empty, green while the count is actually running. That distinction is
-- the entire mechanic -- standing on the tiles is not the same as holding them, since an enemy boot
-- on any of them stops the clock -- so it has to be visible without opening a panel.
function BattleMap:drawObjective()
    local cells = self.overlays and self.overlays.objective
    if not cells or #cells == 0 then return end
    local s = self.size
    local held = self.overlays.objectiveHeld
    -- Amber by default: a `reach` goal has no held state and reads as a destination.
    local r, g, b = 0.95, 0.75, 0.30
    if held == true then r, g, b = 0.40, 0.85, 0.50 end -- counting: green

    -- A slow pulse, so the marked ground reads as live rather than as another terrain type. Shares
    -- self.time with the current-unit highlight, which is already ticking in update().
    local pulse = 0.16 + 0.06 * math.sin((self.time or 0) * 2.2)
    for _, c in ipairs(cells) do
        local wx, wy = self:cellToPixel(c.x, c.y)
        love.graphics.setColor(r, g, b, pulse)
        love.graphics.rectangle("fill", wx + 1, wy + 1, s - 2, s - 2, 3, 3)
        love.graphics.setColor(r, g, b, 0.70)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", wx + 2, wy + 2, s - 4, s - 4, 3, 3)
        love.graphics.setLineWidth(1)
    end
    love.graphics.setColor(1, 1, 1)
end

-- Tile FIELDS: every hazard on the board (self.overlays.hazards -- fire, rain, a Sanctuary, the
-- square a banner holds, a censer's travelling cloud) plus the statuses units carry that are worth
-- showing as ground (self.overlays.unitFields). Handed straight to ui/field_fx.lua, which resolves
-- each one's pattern, composites everything standing on a cell and paints the lot with one shader.
--
-- Full-tile and edge-aware: a field covers its whole cell and feathers only where the footprint
-- actually ends, so a 3x3 blessing reads as one patch of ground rather than nine outlined boxes.
-- Several on a tile STACK -- rain drifting over a Sanctuary shows both -- which the old flat wash,
-- one opaque rect per hazard, could not say at all.
--
-- Sits under the interaction highlights and the units, exactly where the old hazard wash sat: this
-- is scenery, and the thing the player is steering by has to win.
function BattleMap:drawFields()
    self.fields:draw(self, self.overlays)
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

-- Buried charges (self.overlays.charges): the Saboteur's fuses, each a plain record
-- { x, y, side, fuse, spent } (models/combat.lua's Combat.plantCharge). Per-side visibility is the
-- state's call -- like traps, it hands over only the fuses the viewer is allowed to see. Drawn as a
-- small corner pip (a dark disc with a spark rim, tinted by owner side) carrying the turns left on
-- the fuse, kept to the bottom-left so it still reads when a body is standing on the charge.
function BattleMap:drawCharges()
    local s = self.size
    for _, c in ipairs(self.overlays.charges or {}) do
        if not c.spent then
            local wx, wy = self:cellToPixel(c.x, c.y)
            local rad = s * 0.16
            local cx, cy = wx + rad + 6, wy + s - rad - 6
            local r, g, b = 0.90, 0.55, 0.30 -- an enemy fuse smoulders amber...
            if c.side == "party" then r, g, b = 0.40, 0.70, 0.95 end -- ...a party fuse reads blue, like its traps
            love.graphics.setColor(0.06, 0.06, 0.08, 0.9)
            love.graphics.circle("fill", cx, cy, rad)
            love.graphics.setColor(r, g, b, 0.95)
            love.graphics.setLineWidth(2)
            love.graphics.circle("line", cx, cy, rad)
            love.graphics.setLineWidth(1)
            -- The countdown: turns left on the fuse, so a two-turn line reads its clock at a glance.
            love.graphics.setFont(self.numberFont)
            love.graphics.setColor(r, g, b, 1)
            love.graphics.printf(tostring(c.fuse or 0), cx - rad, cy - 7, rad * 2, "center")
        end
    end
    love.graphics.setColor(1, 1, 1)
end

-- Walls (self.overlays.walls): conjured blockers, one runtime object per tile ({ x, y, side,
-- sprite, health, maxHealth }). Always visible to both sides. Drawn as the wall's sprite, or a
-- solid stone-grey block filling most of the tile with a thin HP bar once it has been struck, so it
-- reads as a thing standing in the way. Sits above overlays, under the units.
function BattleMap:drawWalls()
    local s = self.size
    for _, w in ipairs(self.overlays.walls or {}) do
        if w.alive then
            local wx, wy = self:cellToPixel(w.x, w.y)
            local sprite = w.sprite
            if type(sprite) == "userdata" then
                love.graphics.setColor(1, 1, 1)
                local sw, sh = sprite:getDimensions()
                local scale = math.min(s / sw, s / sh)
                love.graphics.draw(sprite, wx + s / 2, wy + s / 2, 0, scale, scale, sw / 2, sh / 2)
            else
                love.graphics.setColor(0.45, 0.47, 0.52, 0.92) -- stone grey
                love.graphics.rectangle("fill", wx + 3, wy + 3, s - 6, s - 6, 3, 3)
                love.graphics.setColor(0.22, 0.23, 0.27, 0.95)
                love.graphics.setLineWidth(2)
                love.graphics.rectangle("line", wx + 3, wy + 3, s - 6, s - 6, 3, 3)
                love.graphics.setLineWidth(1)
            end
            -- Struck wall: a thin amber HP bar along the tile bottom (mirrors damaged traps).
            if w.health and w.maxHealth and w.health < w.maxHealth then
                local ratio = math.max(0, math.min(1, w.health / w.maxHealth))
                local bx, by, bw, bh = wx + 8, wy + s - 12, s - 16, 4
                love.graphics.setColor(0, 0, 0, 0.6)
                love.graphics.rectangle("fill", bx - 1, by - 1, bw + 2, bh + 2, 2, 2)
                love.graphics.setColor(0.9, 0.7, 0.3, 0.95)
                love.graphics.rectangle("fill", bx, by, bw * ratio, bh, 2, 2)
            end
        end
    end
    love.graphics.setColor(1, 1, 1)
end

-- Props (self.overlays.props): the board's own furniture -- barrels, crates -- one runtime object per
-- tile ({ x, y, sprite, health, maxHealth, def }). Sideless and always visible to everyone, so unlike
-- traps there is nothing to filter. Drawn as the prop's sprite, or a rounded block in the blueprint's
-- own `color` while the art is missing, so a rust-red keg reads apart from a pine crate at a glance --
-- which matters, because one of them is a bomb.
--
-- An explosive prop wears a thin dark outline and a lit core, so "that one goes off" is legible without
-- a tooltip. Sits above the overlays and under the units, exactly where the walls sit.
function BattleMap:drawProps()
    local s = self.size
    for _, p in ipairs(self.overlays.props or {}) do
        if p.alive then
            local px, py = self:cellToPixel(p.x, p.y)
            local sprite = p.sprite
            if type(sprite) == "userdata" then
                love.graphics.setColor(1, 1, 1)
                local sw, sh = sprite:getDimensions()
                local scale = math.min(s / sw, s / sh)
                love.graphics.draw(sprite, px + s / 2, py + s / 2, 0, scale, scale, sw / 2, sh / 2)
            else
                local col = (p.def and p.def.color) or { 0.5, 0.45, 0.4 }
                love.graphics.setColor(col[1], col[2], col[3], 0.95)
                love.graphics.rectangle("fill", px + 10, py + 8, s - 20, s - 16, 4, 4)
                love.graphics.setColor(0.14, 0.12, 0.1, 0.95)
                love.graphics.setLineWidth(2)
                love.graphics.rectangle("line", px + 10, py + 8, s - 20, s - 16, 4, 4)
                love.graphics.setLineWidth(1)
                -- A lit core marks the ones that burst when struck (a `explosive`-tagged prop).
                for _, t in ipairs(p.tags or {}) do
                    if t == "explosive" then
                        love.graphics.setColor(1, 0.72, 0.25, 0.9)
                        love.graphics.circle("fill", px + s / 2, py + s / 2, 4)
                        break
                    end
                end
            end
            -- Struck prop: the same thin amber HP bar damaged traps and walls wear.
            if p.health and p.maxHealth and p.health < p.maxHealth then
                local ratio = math.max(0, math.min(1, p.health / p.maxHealth))
                local bx, by, bw, bh = px + 8, py + s - 12, s - 16, 4
                love.graphics.setColor(0, 0, 0, 0.6)
                love.graphics.rectangle("fill", bx - 1, by - 1, bw + 2, bh + 2, 2, 2)
                love.graphics.setColor(0.9, 0.7, 0.3, 0.95)
                love.graphics.rectangle("fill", bx, by, bw * ratio, bh, 2, 2)
            end
        end
    end
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
    local function paint(cells, color)
        cells = cells or {}
        local r, g, b = color[1], color[2], color[3]
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
    -- "Threats" survey: the full enemy danger zone (every tile a foe could reach-and-strike),
    -- purple, painted first so the actor's own blue/red bands sit on top of it. It reads as a flat
    -- band and nothing more: the falling chevron is reserved for HAZARD GROUND now (ui/field_fx.lua),
    -- and threatened air is not ground -- a foe could strike here, but there is nothing underfoot to
    -- step in. Borrowing the hazard shader for it made a whole half-board of empty tiles look salted.
    paint(self.overlays.enemyRanges, Colors.DANGER)
    -- Default-attack (threat) reach in red, under the blue move band. Its cells are the tiles
    -- beyond movement the unit could still strike, so it never overlaps the move set.
    paint(self.overlays.threat, Colors.RANGE)
    -- Reachable move tiles: blue when safe, PURPLE where a foe could also strike this turn (the
    -- intersection of your movement and an enemy's attack range), so a step into danger reads.
    paint(self.overlays.move, Colors.MOVE)
    paint(self.overlays.moveDanger, Colors.DANGER)
    -- Hovered unit's reach (Fire Emblem / Triangle Strategy preview): its movement in blue -- the
    -- same as yours -- and its attack range in red. The state suppresses the actor's own overlays
    -- while a unit is hovered, so the two never paint together.
    paint(self.overlays.inspectMove, Colors.MOVE)
    paint(self.overlays.inspectRange, Colors.RANGE)
    -- Support abilities (heals / buffs) reach in green; offensive ones in red.
    if self.overlays.rangeSupport then
        paint(self.overlays.range, Colors.SUPPORT)
    else
        paint(self.overlays.range, Colors.RANGE)
    end

    -- Area-of-effect footprint: the cells an armed AoE ability would hit if fired at the aimed
    -- cell, drawn OVER (and brighter than) the range wash so the blast reads at a glance -- green
    -- for a friendly area cast, red for a hostile one. Cells can extend past the range set (a blast
    -- that clips tiles you couldn't aim at directly), so it paints its own fill + a bold border.
    if self.overlays.aoe then
        -- A BOON previews as the ground it lays: a buff's rising chevrons, a heal's crosses -- the same
        -- look the resulting field will draw, so the promise and the result are visibly one thing. A
        -- HOSTILE blast does not, and must not: it leaves no hazard behind, and the falling chevron is
        -- reserved for ground that actually harbours one (ui/field_fx.lua). Its red fill + bold outline
        -- below is the whole telegraph -- a box over the tiles it hits, not a stain on them.
        if self.overlays.aoeSupport then
            self.fields:drawTelegraph(self, self.overlays.aoe, {
                category = FieldFx.telegraphCategory(self.overlays.aoeSupport),
                group = "telegraph:aoe",
            })
        end
        local c = self.overlays.aoeSupport and Colors.SUPPORT or Colors.AOE
        local r, g, b = c[1], c[2], c[3]
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

    -- An in-progress CHANNEL's threatened tiles: an ability winding up (an enemy's Meteor Storm, or the
    -- party's own) paints where it WILL land, so units still have turns to step clear before it resolves.
    -- Pulses in an ominous magenta-violet to read as "imminent detonation", distinct from the steady
    -- armed-AoE wash above. Read straight off unit.channel, so it persists across every unit's turn.
    if self.overlays.channelAoe then
        -- Same rule as the armed blast above: a supporting channel previews as the ground it lays
        -- (rising chevrons / heal crosses), but an offensive one leaves no hazard, so it wears only the
        -- pulsing detonation box below -- the falling chevron stays reserved for real hazard ground.
        if self.overlays.channelSupport then
            self.fields:drawTelegraph(self, self.overlays.channelAoe, {
                category = FieldFx.telegraphCategory(self.overlays.channelSupport),
                intensity = 1.0, group = "telegraph:channel",
            })
        end
        local t = 0.5 + 0.5 * math.sin(love.timer.getTime() * 5) -- 0..1 pulse
        for _, c in ipairs(self.overlays.channelAoe) do
            local wx, wy = self:cellToPixel(c.x, c.y)
            love.graphics.setColor(0.90, 0.30, 0.55, 0.20 + 0.20 * t)
            love.graphics.rectangle("fill", wx + 1, wy + 1, s - 2, s - 2)
            love.graphics.setColor(0, 0, 0, 0.5)
            love.graphics.setLineWidth(3)
            love.graphics.rectangle("line", wx + 2, wy + 2, s - 4, s - 4)
            love.graphics.setColor(0.98, 0.50, 0.80, 0.6 + 0.4 * t)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", wx + 2, wy + 2, s - 4, s - 4)
        end
        love.graphics.setLineWidth(1)
    end
end

-- The actor's planned walk route (self.overlays.path): an origin-first list of { x, y } tiles,
-- drawn as a white polyline through the tile centres with an arrowhead at the destination, so
-- the exact path the unit will take reads at a glance (Fire Emblem / Advance Wars). A dark backing
-- stroke under the line keeps it legible over any terrain, mirroring drawOverlays' boundary pass.
-- Only the origin tile holds a unit; every later tile is empty, so the line never hides a token.
function BattleMap:drawMovePath()
    local path = self.overlays.path
    if not path or #path < 2 then return end
    local s = self.size
    local pts = {}
    for _, c in ipairs(path) do
        local wx, wy = self:cellToPixel(c.x, c.y)
        pts[#pts + 1] = wx + s / 2
        pts[#pts + 1] = wy + s / 2
    end
    local prevJoin = love.graphics.getLineJoin()
    love.graphics.setLineJoin("bevel")
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.setLineWidth(3)
    love.graphics.line(pts)
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.setLineWidth(1.5)
    love.graphics.line(pts)

    -- Arrowhead at the destination, pointed along the final segment.
    local n = #pts
    local ex, ey = pts[n - 1], pts[n]
    local ang = math.atan2(ey - pts[n - 2], ex - pts[n - 3])
    local hl = s * 0.15
    local a1, a2 = ang + math.rad(150), ang - math.rad(150)
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.polygon("fill", ex + math.cos(ang) * 2, ey + math.sin(ang) * 2,
        ex + hl * math.cos(a1), ey + hl * math.sin(a1),
        ex + hl * math.cos(a2), ey + hl * math.sin(a2))
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.polygon("fill", ex, ey,
        ex + hl * math.cos(a1), ey + hl * math.sin(a1),
        ex + hl * math.cos(a2), ey + hl * math.sin(a2))

    love.graphics.setLineWidth(1)
    love.graphics.setLineJoin(prevJoin)
    love.graphics.setColor(1, 1, 1)
end

-- Unit bodies: sprite/token + side ring. HP bars and turn numbers are a separate pass
-- (drawUnitInfo) drawn AFTER the highlights so those readouts stay legible on top.
-- An untargetable (Invisible) unit is drawn faded: the player still sees where their own hidden
-- unit stands, and the fade is the cue that the enemy currently cannot reach it.
function BattleMap:drawUnits()
    if not self.combat then return end
    local s = self.size
    -- Corpses first, so a living unit standing on a fallen one always draws on top. A corpse is drawn
    -- as a faint, desaturated token with no side ring -- present enough to mark the tile for a Revive
    -- or Raise Dead, subtle enough not to clutter the board. A body a living unit now stands over is
    -- skipped entirely (it's hidden and unreachable anyway), as is one whose killing blow the fx
    -- controller is still holding back (fx:awaiting) -- the body must not drop before the counter lands.
    for _, u in ipairs(self.combat.units) do
        -- A held summon that arrived dead (conjured onto a trap) is withheld like a living one -- its
        -- body, corpse and all, waits for the cast that made it rather than dropping ahead of the walk.
        if u.corpse and not u.alive and not self:heldUnit(u)
            and not Combat.unitAt(self.combat, u.x, u.y)
            and not (self.fx and self.fx:awaiting(u)) then
            local wx, wy = self:cellToPixel(u.x, u.y)
            -- Centre the corpse token over the body's whole footprint (its anchor cell for a 1×1).
            local bw, bh = (u.w or 1) * s, (u.h or 1) * s
            local cr = math.min(bw, bh) * 0.24
            love.graphics.setColor(0.30, 0.30, 0.34, 0.45)
            love.graphics.circle("fill", wx + bw / 2, wy + bh / 2, cr)
            love.graphics.setColor(0.12, 0.12, 0.14, 0.45)
            love.graphics.setLineWidth(2)
            love.graphics.circle("line", wx + bw / 2, wy + bh / 2, cr)
            love.graphics.setLineWidth(1)
        end
    end
    for _, u in ipairs(self.combat.units) do
        -- Animation modifiers (models the combat controller feeds): a pixel offset (walk slide +
        -- attack lunge + hit shake), a white/red hit flash, and a death fade. A dying unit is
        -- alive=false in the model yet still drawn here while its fade runs, darkening to black over
        -- the corpse token drawn above, before that token takes over. A unit felled by a counter the
        -- controller has not played yet (fx:awaiting) is likewise alive=false with its fade not begun,
        -- and must keep drawing untouched -- otherwise it would blink out and reappear to die.
        local offX, offY, flash, fade = 0, 0, 0, 0
        local glow, gr, gg, gb = 0, 0, 0, 0
        local awaiting = false
        if self:heldUnit(u) then goto continue end -- a summon not yet revealed draws nothing
        if self.fx then
            offX, offY, flash, fade = self.fx:spriteState(u, s)
            glow, gr, gg, gb = self.fx:castGlow(u)
            awaiting = self.fx:awaiting(u)
        end
        if u.alive or fade > 0 or awaiting then
            local wx, wy = self:cellToPixel(u.x, u.y)
            wx, wy = wx + offX, wy + offY
            -- The body fills its whole footprint box (one cell for a 1×1 unit). Sprite and token are
            -- sized to and centred in the box, so a 2×2 ogre draws twice as tall and wide as a man.
            local bw, bh = (u.w or 1) * s, (u.h or 1) * s
            local cx, cy = wx + bw / 2, wy + bh / 2
            local disc = math.min(bw, bh) * 0.32
            local a = fade > 0 and (1 - fade) or (Status.untargetable(u) and 0.40 or 1)
            local tint = 1 - fade -- fade toward black as it dies
            -- No side ring: a faction outline here would sit right on top of the range band's own
            -- boundary stroke (drawOverlays) and the two reds read as one mark. The unit's side is
            -- carried by its HP bar instead -- see drawHpBar / ui/colors.lua.
            local sprite = u.char.sprite
            if type(sprite) == "userdata" then
                local sw, sh = sprite:getDimensions()
                local scale = math.min((bw - 8) / sw, (bh - 8) / sh)
                -- A dying body burns away (dissolve) and a just-arrived one knits in (materialize),
                -- both through shaders/sprite.lua, in place of the old flat fade-to-black. The shader
                -- eats or reveals the sprite along a ragged edge lit by its boundary colour, so a death
                -- reads as a body coming apart rather than a token dimming. Everything else -- a living
                -- unit at rest -- takes the plain tinted draw below, unchanged.
                local mat = self.materialize[u]
                local shader = (fade > 0 or mat) and self:spriteFx()
                if shader then
                    love.graphics.setShader(shader)
                    if fade > 0 then
                        shader:send("uMode", SpriteShader.MODES.dissolve)
                        shader:send("uAmount", fade)
                        shader:send("uEdge", DISSOLVE_EDGE)
                    else
                        shader:send("uMode", SpriteShader.MODES.materialize)
                        shader:send("uAmount", 1 - mat / MATERIALIZE_TIME)
                        shader:send("uEdge", MATERIALIZE_EDGE)
                    end
                    shader:send("uTime", self.time or 0)
                    love.graphics.setColor(1, 1, 1, Status.untargetable(u) and 0.40 or 1)
                    love.graphics.draw(sprite, cx, cy, 0, scale, scale, sw / 2, sh / 2)
                    love.graphics.setShader()
                else
                    love.graphics.setColor(tint, tint, tint, a)
                    love.graphics.draw(sprite, cx, cy, 0, scale, scale, sw / 2, sh / 2)
                end
                if flash > 0 then -- additive pop, so the sprite brightens rather than just recolors
                    love.graphics.setBlendMode("add")
                    love.graphics.setColor(flash * 0.9, flash * 0.5, flash * 0.45, a)
                    love.graphics.draw(sprite, cx, cy, 0, scale, scale, sw / 2, sh / 2)
                    love.graphics.setBlendMode("alpha")
                end
                if glow > 0 then -- the caster's own additive cast glow (a different color from the flash)
                    love.graphics.setBlendMode("add")
                    love.graphics.setColor(gr * glow, gg * glow, gb * glow, a)
                    love.graphics.draw(sprite, cx, cy, 0, scale, scale, sw / 2, sh / 2)
                    love.graphics.setBlendMode("alpha")
                end
            else
                -- Token fallback: colored disc with the unit's initial, in the unit's side colour.
                local c = Colors.unit(u)
                love.graphics.setColor(c[1] * tint, c[2] * tint, c[3] * tint, a)
                love.graphics.circle("fill", cx, cy, disc)
                love.graphics.setFont(self.font)
                love.graphics.setColor(tint, tint, tint, a)
                love.graphics.printf((u.char.name or "?"):sub(1, 1), wx, cy - 8, bw, "center")
                if flash > 0 then
                    love.graphics.setColor(1, 1, 1, flash * 0.6 * a)
                    love.graphics.circle("fill", cx, cy, disc)
                end
                if glow > 0 then
                    love.graphics.setBlendMode("add")
                    love.graphics.setColor(gr * glow, gg * glow, gb * glow, a)
                    love.graphics.circle("fill", cx, cy, disc)
                    love.graphics.setBlendMode("alpha")
                end
            end
        end
        ::continue::
    end
end

-- The tile-top-left a unit's READOUTS hang off: its cell, carried along by whatever slide it is in the
-- middle of. A body being shoved or walked across the board takes its HP bar, turn number and status
-- badges with it -- measured from the model's cell alone they would snap to the destination tile on the
-- first frame and sit there while the sprite was still travelling, the readouts arriving before the
-- unit does.
--
-- The SLIDE only, not the whole spriteState the sprite gets (drawUnits): a bar that inherited the hit
-- shake or the attack lunge would jitter, and these are things you read rather than watch. Same choice,
-- for the same reason, as the damage floaters (CombatFx:drawFloaters).
--
-- Shared by the readout draws and the badge hover hit-test (statusAt), so a tooltip lands on the badge
-- actually under the cursor rather than on where it will eventually come to rest.
function BattleMap:unitOrigin(u)
    local wx, wy = self:cellToPixel(u.x, u.y)
    if not self.fx then return wx, wy end
    local sx, sy = self.fx:slideOffset(u, self.size)
    return wx + sx, wy + sy
end

-- HP bars + turn-order numbers, drawn last (above highlights) so they're never tinted.
function BattleMap:drawUnitInfo()
    if not self.combat then return end
    local orderIndex = {}
    local order = Combat.turnOrder(self.combat)
    -- Anchor the acting unit at #1 until the UI hands off: its initiative is charged the instant it acts
    -- (a beat before battle.current switches), which would otherwise flip its board token to a later
    -- number while its attack still plays. Mirrors the turn strip (states/battle.lua refreshView).
    local acting = self.overlays and self.overlays.current and self.overlays.current.unit
    if acting then
        for i, u in ipairs(order) do
            if u == acting then table.remove(order, i); table.insert(order, 1, u); break end
        end
    end
    for i, u in ipairs(order) do orderIndex[u] = i end
    -- Remember each living unit's turn number so a just-felled unit keeps the number it held while its
    -- death fade runs (it drops out of turnOrder the instant the model kills it -- see orderBy). Mirrors
    -- the turn strip's dyingCards / lastLayout (ui/combat_panel.lua).
    self.lastOrderIndex = self.lastOrderIndex or {}
    for u, i in pairs(orderIndex) do self.lastOrderIndex[u] = i end
    for _, u in ipairs(self.combat.units) do
        -- A felled unit is alive=false in the model at once, but its HP bar and turn number must stay up
        -- (draining / fading) until the blow that killed it has actually played -- otherwise they pop
        -- away a beat before the damage animation, giving the death away. Keep drawing them while the fx
        -- controller is fading the body out (deathFade) or still holds an unplayed killing blow
        -- (awaiting), matching drawUnits and the turn strip; the fade dims them out with the body.
        local fade = self.fx and self.fx:deathFade(u)
        local awaiting = self.fx and self.fx:awaiting(u)
        -- A held summon draws no body (drawUnits skips it), so it carries no readouts either -- they
        -- would otherwise float over an empty tile ahead of the cast that conjures it.
        if self:heldUnit(u) then
            -- nothing
        elseif u.alive or fade or awaiting then
            local wx, wy = self:unitOrigin(u)
            local alpha = fade and (1 - fade) or 1
            self:drawHpBar(u, wx, wy, alpha)
            self:drawTurnNumber(orderIndex[u] or self.lastOrderIndex[u], wx, wy, alpha)
            if u.alive then self:drawStatusBadges(u, wx, wy) end
        elseif self.lastOrderIndex[u] then
            self.lastOrderIndex[u] = nil -- fully gone: drop its stale number
        end
    end
end

-- Badge row geometry. The row must live inside the tile, which is only BADGE_INSET*2 shy of 60px
-- wide, so BADGE_W is a ceiling rather than a fixed width: badges narrow toward BADGE_MIN_W as the
-- statuses pile up (ui/status_badge.lua squeezes the abbr to whatever width it is handed). Below
-- BADGE_MIN_W an abbr is unreadable, so the row stops shrinking and overflows into a "+n" instead.
local BADGE_W, BADGE_MIN_W, BADGE_H, BADGE_GAP, BADGE_INSET = 18, 11, 12, 2, 4

-- The on-screen rect of each active status badge on unit `u` (whose tile top-left is wx, wy):
-- a right-justified row along the tile's bottom, just above the HP bar. Shared by the badge
-- draw and the hover hit-test (statusAt) so a tooltip lands exactly on the badge pointed at.
-- A rect carries either `st` (a status) or `more` (the count the row had no room for).
function BattleMap:statusBadgeRects(u, wx, wy)
    local list = u.statuses
    if not list or #list == 0 then return {} end
    local s = self.size
    -- Lay the badge row along the bottom of the body's whole footprint (its one cell for a 1×1 unit),
    -- so a wide body's badges spread across its width and sit just above its footprint-wide HP bar.
    local boxW, boxH = (u.w or 1) * s, (u.h or 1) * s
    local inner = boxW - BADGE_INSET * 2
    local gap = BADGE_GAP

    -- How many slots the row shows, and how wide each is: every status if they still fit at
    -- BADGE_MIN_W, else as many as do -- the last of which is spent on the "+n" marker.
    local slots, bw = #list, math.floor((inner - (#list - 1) * gap) / #list)
    if bw < BADGE_MIN_W then
        slots = math.max(1, math.floor((inner + gap) / (BADGE_MIN_W + gap)))
        bw = math.floor((inner - (slots - 1) * gap) / slots)
    end
    bw = math.min(bw, BADGE_W)

    local shown = (slots < #list) and (slots - 1) or #list
    local totalW = slots * bw + (slots - 1) * gap
    local startX = wx + boxW - BADGE_INSET - totalW
    -- The HP bar's black backing tops out at wy + boxH - 9; sit the badges a couple px above it.
    local by = wy + boxH - 11 - BADGE_H
    local rects = {}
    for i = 1, slots do
        local r = { x = startX + (i - 1) * (bw + gap), y = by, w = bw, h = BADGE_H }
        if i <= shown then r.st = list[i] else r.more = #list - shown end
        rects[i] = r
    end
    return rects
end

-- Active status effects as small badges right-justified along the tile's bottom, sitting just
-- above the HP bar. Each badge shows the status def's `abbr` in its `color`, so a stunned/rooted
-- unit reads at a glance. Reads unit.statuses (runtime data), never love.graphics at require-time.
function BattleMap:drawStatusBadges(u, wx, wy)
    for _, r in ipairs(self:statusBadgeRects(u, wx, wy)) do
        if r.st then
            StatusBadge.draw(r.st, r.x, r.y, r.w, r.h)
        else
            StatusBadge.drawMore(r.more, r.x, r.y, r.w, r.h)
        end
    end
end

-- The status instance whose badge is under (px, py), or nil. Walks living units' badge rects
-- so the battle state can show a shared tooltip (ui/status_tooltip.lua) for the hovered status.
function BattleMap:statusAt(px, py)
    if not self.combat then return nil end
    for _, u in ipairs(self.combat.units) do
        if u.alive then
            local wx, wy = self:unitOrigin(u)
            for _, r in ipairs(self:statusBadgeRects(u, wx, wy)) do
                if r.st and px >= r.x and px <= r.x + r.w and py >= r.y and py <= r.y + r.h then
                    return r.st
                end
            end
        end
    end
    return nil
end

-- Thin HP bar along the bottom of the unit's tile, filled in the unit's SIDE colour (blue ally /
-- red foe) -- with no ring on the token, this bar is what says whose unit this is. The hue is spent
-- on the side, so how hurt the unit is reads from the bar's length, darkened toward empty by
-- Colors.drain rather than shifting hue.
-- `alpha` (default 1) fades the whole bar out with the body as a felled unit dies (drawUnitInfo).
function BattleMap:drawHpBar(u, wx, wy, alpha)
    local s = self.size
    local al = alpha or 1
    local hp = u.char.stats.health
    local side = Colors.unit(u)
    -- The shown value lags the model so the bar drains smoothly toward the new HP after a hit; the
    -- aimed-action preview slice below still projects off the true current HP.
    local shown = (self.fx and self.fx:displayHp(u)) or (hp and hp.current) or 0
    local ratio = 0
    if hp and hp.max and hp.max > 0 then ratio = math.max(0, math.min(1, shown / hp.max)) end
    -- Span the bar across the body's whole footprint and sit it along the box's bottom edge, so a
    -- wide unit gets a wide bar rather than one hugging its top-left cell. 1×1 is the original geometry.
    local boxW, boxH = (u.w or 1) * s, (u.h or 1) * s
    local bx, by, bw, bh = wx + 4, wy + boxH - 8, boxW - 8, 5
    love.graphics.setColor(0, 0, 0, 0.6 * al)
    love.graphics.rectangle("fill", bx - 1, by - 1, bw + 2, bh + 2, 2, 2)

    -- Aimed-action preview: project the hovered cast's damage/heal onto this unit's HP bar so the
    -- incoming hit reads on the board too (mirrors the turn strip's drawResourceBar). No preview =
    -- a plain fill.
    local pv = self.overlays.hpPreview and self.overlays.hpPreview[u]
    local delta = pv and ((pv.heal or 0) - (pv.damage or 0)) or 0
    if delta ~= 0 and hp and hp.max and hp.max > 0 then
        local afterRatio = math.max(0, math.min(1, (hp.current + delta) / hp.max))
        local dr, dg, db = Colors.drain(side, ratio)
        love.graphics.setColor(dr, dg, db, al)
        love.graphics.rectangle("fill", bx, by, bw * math.min(ratio, afterRatio), bh, 2, 2)
        if delta < 0 then -- the HP about to be lost: amber, since red would vanish on a foe's red bar
            local c = pv.lethal and Colors.LETHAL or Colors.PENDING
            love.graphics.setColor(c[1], c[2], c[3], 0.95 * al)
            love.graphics.rectangle("fill", bx + bw * afterRatio, by, bw * (ratio - afterRatio), bh, 2, 2)
        else -- green slice for the HP about to be gained
            local c = Colors.HEALING
            love.graphics.setColor(c[1], c[2], c[3], 0.9 * al)
            love.graphics.rectangle("fill", bx + bw * ratio, by, bw * (afterRatio - ratio), bh, 2, 2)
        end
    else
        local dr, dg, db = Colors.drain(side, ratio)
        love.graphics.setColor(dr, dg, db, al)
        love.graphics.rectangle("fill", bx, by, bw * ratio, bh, 2, 2)
    end
end

-- Turn-order number in the tile's top-left, with a dark backing for legibility.
function BattleMap:drawTurnNumber(n, wx, wy, alpha)
    if not n then return end
    local al = alpha or 1
    love.graphics.setColor(0, 0, 0, 0.7 * al)
    love.graphics.rectangle("fill", wx + 1, wy + 1, 16, 15, 3, 3)
    love.graphics.setFont(self.numberFont)
    love.graphics.setColor(0.98, 0.95, 0.7, al)
    love.graphics.printf(tostring(n), wx + 1, wy + 1, 16, "center")
end

-- Emphasise the acting unit (pulsing gold ring, always), the unit the timeline is hovering (steady
-- cyan ring), and whoever the hovered combat-log line names (pulsing white ring). Colours are
-- distinct so no two ever read as the same thing.
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
        -- Ring the acting unit's whole footprint (it carries its own unit, so its size is known here),
        -- so a 2×2 body gets a 2×2 gold ring rather than one framing only its anchor cell.
        local cw = (current.unit and current.unit.w or 1) * s
        local ch = (current.unit and current.unit.h or 1) * s
        local pulse = 0.65 + 0.35 * math.sin((self.time or 0) * 4)
        love.graphics.setColor(0.98, 0.82, 0.35, 0.13)
        love.graphics.rectangle("fill", wx + 2, wy + 2, cw - 4, ch - 4, 5, 5)
        love.graphics.setColor(0.98, 0.82, 0.35, pulse)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", wx + 3, wy + 3, cw - 6, ch - 6, 5, 5)
        love.graphics.setLineWidth(1)
    end

    -- Whoever the hovered combat-log line is about: a pulsing white ring, deliberately a third colour
    -- (gold = acting, cyan = pointed at, white = the log is talking about this one). When a line names
    -- two -- a striker and the struck -- a thread joins the first to the rest, so the pair reads as
    -- one event. Drawn above the other rings: it answers a question the player just asked.
    local subjects = self.overlays.logSubjects
    if subjects and #subjects > 0 then
        local pulse = 0.55 + 0.45 * math.sin((self.time or 0) * 5)
        local ax, ay = self:cellToPixel(subjects[1].x, subjects[1].y)
        if #subjects > 1 then
            love.graphics.setColor(1, 1, 1, 0.20 + 0.25 * pulse)
            love.graphics.setLineWidth(2)
            for i = 2, #subjects do
                local bx, by = self:cellToPixel(subjects[i].x, subjects[i].y)
                love.graphics.line(ax + s / 2, ay + s / 2, bx + s / 2, by + s / 2)
            end
        end
        for _, m in ipairs(subjects) do
            local wx, wy = self:cellToPixel(m.x, m.y)
            love.graphics.setColor(1, 1, 1, 0.10)
            love.graphics.rectangle("fill", wx + 2, wy + 2, s - 4, s - 4, 4, 4)
            love.graphics.setColor(1, 1, 1, 0.55 + 0.40 * pulse)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", wx + 1, wy + 1, s - 2, s - 2, 4, 4)
        end
        love.graphics.setLineWidth(1)
    end

    self:drawTargetLines()
end

-- Target lines (models/intent.lua, assembled in states/battle.lua): a line from each enemy to the
-- mark it will strike, tinted by the KIND of thing it is about to do -- red for a blow, purple for a
-- spell, green toward an ally it will mend, amber for a hex. So "who is this one going for, and what
-- will it do" reads off the board without opening anything (Into the Breach / Slay the Spire).
--
-- A `retargeted` line is the answer to a step being weighed: this foe would WHEEL onto the actor if
-- it stood on the previewed tile. It is drawn hot -- thicker and pulsing -- so the wall of red that
-- means "do not stand here" is unmistakable, while a calm line to some other body means "busy with
-- them, safe to pass". The arrowhead lands on the target, the origin carries a small dot, so a single
-- line still reads as a direction and not just a streak.
function BattleMap:drawTargetLines()
    local lines = self.overlays.targetLines
    if not lines or #lines == 0 then return end
    local s = self.size
    local pulse = 0.5 + 0.5 * math.sin((self.time or 0) * 6)
    for _, l in ipairs(lines) do
        local col = Colors.INTENT[l.kind] or Colors.RANGE
        local fwx, fwy = self:cellToPixel(l.from.x, l.from.y)
        local twx, twy = self:cellToPixel(l.to.x, l.to.y)
        local fx, fy = fwx + s / 2, fwy + s / 2
        local tx, ty = twx + s / 2, twy + s / 2
        local hot = l.retargeted
        local a = hot and (0.55 + 0.4 * pulse) or 0.55
        local w = hot and (1.25 + pulse) or 1

        -- Dark backing stroke, then the coloured line -- legible over same-hue ground the way the
        -- overlay boundaries are (drawOverlays).
        love.graphics.setColor(0, 0, 0, 0.45 * a + 0.15)
        love.graphics.setLineWidth(w + 1)
        love.graphics.line(fx, fy, tx, ty)
        love.graphics.setColor(col[1], col[2], col[3], a)
        love.graphics.setLineWidth(w)
        love.graphics.line(fx, fy, tx, ty)

        -- Origin dot (which foe) and an arrowhead at the mark (whom), pointed along the line.
        love.graphics.circle("fill", fx, fy, hot and 1.75 or 1.25)
        local ang = math.atan2(ty - fy, tx - fx)
        local hl = s * (hot and 0.15 or 0.12)
        local a1, a2 = ang + math.rad(152), ang - math.rad(152)
        love.graphics.polygon("fill", tx, ty,
            tx + hl * math.cos(a1), ty + hl * math.sin(a1),
            tx + hl * math.cos(a2), ty + hl * math.sin(a2))
    end
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1)
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


