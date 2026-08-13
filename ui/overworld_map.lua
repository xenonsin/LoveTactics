-- Scrolling overworld renderer + input, driven by a models/overworld.lua grid.
-- Like ui/building_map.lua it supports mouse + keyboard + gamepad; the input moves
-- a player token along the trail network (hold a direction to keep walking; single
-- taps move one tile) and the camera follows. Stepping onto an encounter tile fires
-- opts.onEncounter(cell) -- and opts.onApproach(cell) one beat earlier, while the token still stands on
-- the tile before it; keys and material caches are picked up automatically (opts.onPickup announces
-- what was taken), and a key unlocks its gate.
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
local InputMode = require("input_mode") -- which device is live, for the hovered-fight readout
local Sprite = require("models.sprite")
local Tileset = require("models.tileset")
local Muster = require("models.muster") -- for BAND -> pip count; the comparison itself is the caller's
local Patrol = require("models.patrol") -- the fights that walk their beat (models/patrol.lua)
local Theme = require("ui.theme")

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
    self.onArrive = opts.onArrive -- fired on EVERY landed tile (per-step abilities: forage, scouting)
    -- Fired the instant BEFORE the token steps onto an un-engaged encounter, while it still stands on
    -- the tile it is leaving and nothing about the step has happened yet. The autosave seam: see :step.
    self.onApproach = opts.onApproach
    -- Fired when a walked-over marker pays out: onPickup(kind, payload, cell) with kind "cache" or
    -- "key". These are the only two markers that give something WITHOUT opening a panel, so without
    -- this the board takes them in silence and the mark on the trail never explains itself. See :arrive.
    self.onPickup = opts.onPickup
    -- How a fight stands against the company that would field against it: musterBand(cell) -> a
    -- models/muster.lua band name, or nil for a cell with no reading. The widget stays dumb about the
    -- comparison itself (it owns no roster); it only colours what it is told. See the pips in :draw.
    self.musterBand = opts.musterBand
    self.font = opts.font or Theme.body(16)
    self.hoverCell = nil -- the cell under the mouse, for the HUD's fight readout (see hoveredFight)
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
    -- Materials picked out of caches this run, { materialId = count }. Held on the widget rather than
    -- banked to the player on pickup: a map regenerates on re-entry, so paying at pickup would pay
    -- again every time a quest was abandoned and restarted. Quest.complete merges this in (see
    -- states/game.lua), which also means the advancement panel names the haul with the rest of the
    -- spoils rather than as a silent number that changed somewhere.
    self.cacheHaul = {}

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
-- A patrol dressed as the cell its fight is on, so states/game.lua's encounter plumbing -- which has
-- always been handed a cell -- needs no fork. The proxy exists for one field: marking the stop cleared
-- has to clear the PATROL, because the patrol is what carries the fight now and the tile it happens to
-- be standing on carries nothing. Without that a beaten patrol would come back the moment it moved.
local function patrolCell(p, from, foeFrom)
    return setmetatable({ x = p.x, y = p.y, encounter = p.encounter, patrol = p,
                          from = from, foeFrom = foeFrom }, {
        __newindex = function(t, k, v)
            if k == "cleared" and v then p.cleared = true end
            rawset(t, k, v)
        end,
    })
end

-- CONTACT, from either side.
--
-- `from` is the tile the COMPANY was standing on when it happened, which decides which edge of the
-- locked board is theirs (Arena.fromGrid). Walk into something head-on and you meet it head-on; let it
-- catch you while you are deep in a spur and it is between you and the way out. Same composition, same
-- tier, completely different problem -- and decided by how you handled the approach rather than by a
-- roll. That is what makes a moving fight worth having at all.
function OverworldMap:engage(p, from, foeFrom)
    self.heldDir = nil
    self.autoPath = nil
    local cell = patrolCell(p, from or { x = self.px, y = self.py }, foeFrom)
    if self.onApproach then self.onApproach(cell) end
    if self.onEncounter then self.onEncounter(cell) end
    return true
end

function OverworldMap:step(dx, dy)
    local nx, ny = self.px + dx, self.py + dy
    if not self.grid:isWalkable(nx, ny, self.keysHeld) then return false end

    -- Walking INTO something. A swap is caught here too: the tile it stands on is the tile it is about
    -- to leave, and stepping onto it is contact either way (P4).
    local blocking = Patrol.at(self.grid, nx, ny)
    -- Walking into it: the company is still on the tile it is stepping FROM, which is its side.
    if blocking then return not self:engage(blocking, { x = self.px, y = self.py }) end
    -- About to walk into an un-engaged stop: hand the caller this moment FIRST, before the token moves,
    -- the fog lifts, or :arrive fires anything. states/game.lua autosaves here, so a run saved on the
    -- brink of a fight resumes standing one tile shy of it -- in the overworld, free to open the Loadout
    -- -- rather than being dropped straight back into the battle. Everything the step then grants (a
    -- step ability's forage, the revealed fog) is outside the snapshot, so re-walking it grants it once.
    local dest = self.grid:get(nx, ny)
    if self.onApproach and dest and dest.encounter and not dest.cleared then self.onApproach(dest) end
    self.slidePrevX, self.slidePrevY = self.px, self.py -- slide the token from here
    self.slideT = self.slideDur
    self.px, self.py = nx, ny
    -- Lift the fog around the new tile, keeping how much of it was NEW: a step into unmapped country
    -- discovers cells, a step back across known ground discovers none, and the per-step hooks are told
    -- which this was (see onArrive) so an explore-for-coin reward can't be farmed by pacing a cleared map.
    local revealed = self.grid:reveal(self.px, self.py, self.visionRadius)
    self:updateCamera()
    if self:arrive(revealed) then return false end

    -- THE STEP CLOCK. The party moved, so everything else on the board moves once -- which is the whole
    -- of P1, and also the whole of "the map locks during combat": nothing here ticks except on your
    -- step, and during a fight you are not stepping.
    --
    -- Ticked AFTER arriving, so a stop you walked onto opens before anything walks into you: meeting two
    -- fights on one step is a state the encounter panel has no way to show.
    local caught = Patrol.tick(self.grid, { x = self.px, y = self.py })
    -- It walked into US. The company stands where it stands, and the patrol is arriving from its own
    -- tile -- so the side it touched from is the side it deploys on.
    if caught then
        return not self:engage(caught,
            (self.slidePrevX and { x = self.slidePrevX, y = self.slidePrevY }) or { x = self.px, y = self.py },
            { x = caught.prevX or caught.x, y = caught.prevY or caught.y })
    end
    return true
end

-- React to landing on a tile: pick up keys, trigger encounters. Returns true when
-- it opened an encounter panel, so the caller can halt any in-progress hold-to-move.
function OverworldMap:arrive(revealed)
    local c = self.grid:get(self.px, self.py)
    -- Every landed tile: the per-step abilities hook (Kaya's forage, Saber's steps, Gyeom's scouting).
    -- Fired before keys/encounters so a step's reward is banked even on a tile that also opens a fight.
    if self.onArrive then self.onArrive(c, revealed or 0) end
    if c.key and not self.keysHeld[c.key.keyId] then
        self.keysHeld[c.key.keyId] = true
        c.picked = true
        if self.onPickup then self.onPickup("key", c.key, c) end
    end
    if c.cache and not c.picked then
        for id, n in pairs(c.cache.materials or {}) do
            self.cacheHaul[id] = (self.cacheHaul[id] or 0) + n
        end
        c.picked = true
        -- Announced AFTER the haul is banked, so the line a player reads is the haul they now hold.
        if self.onPickup then self.onPickup("cache", c.cache, c) end
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
    self.fogTime = (self.fogTime or 0) + (dt or 0) -- the fog shader's drift clock
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

-- A combat/elite marker says how the fight stands AGAINST THE COMPANY, in two marks that answer two
-- different questions (models/muster.lua):
--
--   * the BOX COLOUR answers "is this a fight at all?" -- the hostile red/orange it has always worn,
--     or, once the company has plainly outgrown it, a calm slate that reads as spent ground. That is
--     also the tile that will offer to be walked off when you step on it (Muster.WALK_OVER), so the
--     colour going calm IS the offer, seen from across the board;
--   * the PIPS answer "and by how much is it above me?" -- one per step, none at all for a fight that
--     is even or beneath you.
--
-- The pips used to count the authored TIER, which is a fact about the encounter table rather than
-- about this run: the same three dots whether the company walked in naked or fully forged. Counting
-- steps above you instead means the mark moves as the company does, which is the only version of it
-- worth reading.
--
-- An even fight draws NO pips and stays red. That pairing is deliberate: "no pips" must not read as
-- "safe", so the thing that says safe is the colour, and the pips only ever count danger past even.
-- Outgrown: a cool slate, and deliberately NOT a green. Green on a map reads as "something good here,
-- go and get it", and this is still a fight -- what it is is beneath notice. Kept light enough that it
-- cannot be mistaken for a CLEARED marker, which is the ordinary hostile colour at 0.3 alpha.
local CALM_MARKER = { 0.46, 0.56, 0.55 }
local PIP_COLOR = { 1.0, 0.86, 0.55 }    -- warning bone-gold, legible on the hostile box beneath it

local function markerColor(kind)
    if kind == "objective" then return 0.95, 0.75, 0.20 end
    if kind == "elite" then return 0.95, 0.55, 0.15 end
    if kind == "town" then return 0.85, 0.85, 0.90 end
    if kind == "treasure" then return 0.35, 0.80, 0.55 end
    if kind == "event" then return 0.60, 0.60, 0.95 end   -- a story stop, not a fight
    if kind == "rest" then return 0.45, 0.80, 0.80 end     -- a safe breather
    if kind == "relic_cache" then return 0.80, 0.52, 0.92 end -- a reliquary: a run relic waits inside
    if kind == "shrine" then return 0.88, 0.40, 0.48 end       -- a sin's altar: a Vice for a toll
    if kind == "merchant" then return 0.90, 0.74, 0.32 end      -- a wandering market: goods for gold
    if kind == "crossroads" then return 0.70, 0.72, 0.80 end     -- a branching dilemma: a gamble
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

-- A faceted gem: a reliquary holding a run relic (models/relic.lua).
function MarkerIcon.relic_cache(x, y, w, h, r, g, b, a)
    local cx = x + w / 2
    local top = y + h * 0.12
    local shoulder = y + h * 0.42
    love.graphics.setColor(r, g, b, a)
    love.graphics.polygon("fill",
        cx, top, x + w, shoulder, cx, y + h, x, shoulder)
    -- Two facet lines catching the light, shaded off the base colour.
    love.graphics.setColor(r * 0.45, g * 0.45, b * 0.45, a)
    love.graphics.setLineWidth(1)
    love.graphics.line(x, shoulder, x + w, shoulder)
    love.graphics.line(cx, top, cx, y + h)
end

-- A signpost fork: a crossroads dilemma, two ways to weigh.
function MarkerIcon.crossroads(x, y, w, h, r, g, b, a)
    love.graphics.setColor(r, g, b, a)
    love.graphics.setLineWidth(2)
    local cx = x + w / 2
    love.graphics.line(cx, y + h, cx, y + h * 0.5)        -- the post
    love.graphics.line(cx, y + h * 0.5, x + w * 0.1, y + h * 0.2) -- left arm
    love.graphics.line(cx, y + h * 0.5, x + w * 0.9, y + h * 0.2) -- right arm
    love.graphics.setLineWidth(1)
end

-- A coin: a wandering merchant selling goods for gold.
function MarkerIcon.merchant(x, y, w, h, r, g, b, a)
    local cx, cy = x + w / 2, y + h / 2
    love.graphics.setColor(r, g, b, a)
    love.graphics.circle("fill", cx, cy, w * 0.42)
    love.graphics.setColor(r * 0.4, g * 0.4, b * 0.4, a)
    love.graphics.setLineWidth(2)
    love.graphics.line(cx, cy - h * 0.22, cx, cy + h * 0.22) -- a struck "coin" mark
    love.graphics.setLineWidth(1)
end

-- An altar under a flame: a shrine that trades a Vice for a toll.
function MarkerIcon.shrine(x, y, w, h, r, g, b, a)
    love.graphics.setColor(r, g, b, a)
    -- Altar block.
    love.graphics.rectangle("fill", x + w * 0.18, y + h * 0.55, w * 0.64, h * 0.45, 2, 2)
    -- A flame licking up off it.
    love.graphics.polygon("fill", x + w * 0.5, y + h * 0.1,
        x + w * 0.66, y + h * 0.5, x + w * 0.5, y + h * 0.42, x + w * 0.34, y + h * 0.5)
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
    self:drawPatrols() -- the fights that walk: their circuit, their next tile, and what they are doing
    self:drawFog() -- covers undiscovered tiles + their markers; player stays on top
    self:drawPlayer()

    love.graphics.pop()
end

-- The fog shader (shaders/fog.lua), compiled once on first draw and latched on failure so a driver
-- that refuses it drops back to the flat rects forever -- the same tolerance ui/field_fx.lua gives its
-- own shader. Returns the shader or nil.
function OverworldMap:fogFx()
    if self.fogShader then return self.fogShader end
    if self.fogFailed then return nil end
    local ok, sh = pcall(love.graphics.newShader, require("shaders.fog").source)
    if not ok or not sh then
        self.fogFailed = true
        return nil
    end
    local data = love.image.newImageData(1, 1)
    data:setPixel(0, 0, 1, 1, 1, 1)
    self.fogPx = love.graphics.newImage(data)
    self.fogShader = sh
    return sh
end

-- Fog of war overlay (drawn after markers so it hides markers on hidden tiles).
-- Three tiers: undiscovered tiles are near-opaque churning mist; discovered tiles outside
-- the current (circular) vision radius are veiled; tiles within vision are left
-- untouched. Uses the grid's shared inVision test so it matches what reveal lit.
--
-- Each fogged tile is drawn through shaders/fog.lua, which samples its churn in BOARD space (uCell) so
-- a whole unexplored region rolls as one dark mass instead of a grid of identical black squares. If the
-- shader is unavailable it falls back to the flat rects this always drew.
function OverworldMap:drawFog()
    local s = self.grid.size
    local r = self.visionRadius
    local sh = self:fogFx()

    if not sh then
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
        return
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setShader(sh)
    sh:send("uTime", self.fogTime or 0)
    for y = 1, self.grid.rows do
        for x = 1, self.grid.cols do
            local c = self.grid:get(x, y)
            local alpha
            if not c.seen then
                alpha = 0.98
            elseif not self.grid:inVision(self.px, self.py, x, y, r) then
                alpha = 0.5
            end
            if alpha then
                local wx, wy = self.grid:cellToPixel(x, y)
                sh:send("uCell", { x, y })
                sh:send("uAlpha", alpha)
                love.graphics.draw(self.fogPx, wx, wy, 0, s, s)
            end
        end
    end
    love.graphics.setShader()
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

            -- Material cache: the reason a dead end is worth the walk. An ingot wedge rather than a
            -- letter, so it never reads as another kind of encounter -- it costs no fight and opens no
            -- panel, it is simply picked up on arrival. Copper against the key's gold: the same "walk
            -- here and take it" family, a different thing in it. Sized and darkly outlined to carry at
            -- 32px over a pale trail, because it is visible through the fog like every other marker,
            -- and that is the whole point -- the detour has to be a decision made in advance.
            if c.cache and not c.picked then
                local pad = s * 0.22
                local x1, y1 = wx + s / 2, wy + pad
                local x2, y2 = wx + s - pad, wy + s - pad
                local x3, y3 = wx + pad, wy + s - pad
                love.graphics.setColor(0.12, 0.09, 0.06, 0.75)
                love.graphics.polygon("fill", x1, y1 - 1, x2 + 1, y2 + 1, x3 - 1, y3 + 1)
                love.graphics.setColor(0.90, 0.62, 0.30)
                love.graphics.polygon("fill", x1, y1, x2, y2, x3, y3)
                love.graphics.setColor(1, 0.86, 0.62)
                love.graphics.setLineWidth(1.5)
                love.graphics.polygon("line", x1, y1, x2, y2, x3, y3)
                love.graphics.setLineWidth(1)
            end

            if c.encounter then
                local kind = c.encounter.kind
                local r, g, b = markerColor(kind)
                -- How this fight stands against the company, asked once and spent twice below: on the
                -- box colour and on the pips. Nil for a stop there is no comparison to make about --
                -- a treasure, a rest, an escort fight the muster cannot price -- which keeps its
                -- ordinary hostile colour and draws no pips, exactly as before any of this existed.
                local band = self.musterBand and self.musterBand(c) or nil
                if band == "beneath" then r, g, b = CALM_MARKER[1], CALM_MARKER[2], CALM_MARKER[3] end
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

                -- How far above the company this fight stands: one pip per step, along the marker's
                -- bottom edge. None at all when it is even or beneath them -- the box colour above has
                -- already said which of those two it is.
                --
                -- Sized to be COUNTED, which the old tier pips were not: they were `s * 0.06`, under 2px
                -- across at a 32px tile, and three of them could not be told from two. They got away
                -- with it only because their colour ALSO encoded the tier (green -> amber -> red), so
                -- nobody was counting -- they were reading "red". Now that the count carries a fact of
                -- its own, it has to survive being read.
                local steps = band and Muster.PIPS[band] or 0
                if steps > 0 and (kind == "combat" or kind == "elite") then
                    local pipR = math.max(2.5, s * 0.09)
                    local gap = pipR * 2 + 2
                    local w = steps * gap - 2
                    local cy = wy + s - pipR - 2

                    -- A dark seat behind the row, because the pips land on the marker's own hostile red
                    -- and a warning mark that needs good luck with the background is not a warning.
                    love.graphics.setColor(0.05, 0.05, 0.07, a * 0.85)
                    love.graphics.rectangle("fill", wx + s / 2 - w / 2 - 3, cy - pipR - 1.5,
                        w + 6, pipR * 2 + 3, pipR + 1.5, pipR + 1.5)

                    love.graphics.setColor(PIP_COLOR[1], PIP_COLOR[2], PIP_COLOR[3], a)
                    for i = 1, steps do
                        love.graphics.circle("fill", wx + s / 2 - w / 2 + pipR + (i - 1) * gap, cy, pipR)
                    end
                end
                love.graphics.setColor(1, 1, 1)
            end
        end
    end
end

-- A patrol's state, as the marker's colour. Beat keeps the hostile red every fight has always worn;
-- Alert is the warm gold the board already uses for "live, act now"; Return is a cool slate.
--
-- The slate is deliberately DARKER than the outgrown-fight slate (CALM_MARKER): those two must not be
-- confused, because one means "beneath your notice" and the other means "has just lost you and is
-- walking home", which are opposite invitations.
local PATROL_STATE = {
    beat = { 0.86, 0.28, 0.22 },
    alert = { 0.95, 0.72, 0.24 },
    return_ = { 0.42, 0.48, 0.55 },
}

-- WHERE IT WILL BE, drawn before you commit your own step. A moving fight you cannot predict is a
-- punishment; one whose circuit you can read is a puzzle. Three marks, on revealed ground only:
--
--   the beat    a faint dotted circuit -- the schedule, on ground you have already mapped
--   the pip     the tile it occupies NEXT, so the exchange is legible before you move
--   the colour  what it is doing (see PATROL_STATE)
--
-- The preview is side-effect free: Patrol.preview walks a copy, because a telegraph that advanced the
-- thing it was describing would be a bug the player could farm -- the same rule the battle's enemy
-- intent telegraph already follows.
function OverworldMap:drawPatrols()
    local grid = self.grid
    if not grid.patrols then return end
    local s = grid.size
    for _, p in ipairs(grid.patrols) do
        local here = grid:get(p.x, p.y)
        if not p.cleared and here and here.seen then
            -- The circuit, on mapped ground only.
            love.graphics.setColor(0.86, 0.28, 0.22, 0.16)
            for _, b in ipairs(p.beat or {}) do
                local c = grid:get(b.x, b.y)
                if c and c.seen then
                    local wx, wy = grid:cellToPixel(b.x, b.y)
                    love.graphics.rectangle("fill", wx + 4, wy + 4, s - 8, s - 8, 2)
                end
            end

            local nx, ny = Patrol.preview(grid, p, { x = self.px, y = self.py })
            if nx and (nx ~= p.x or ny ~= p.y) then
                local c = grid:get(nx, ny)
                if c and c.seen then
                    local wx, wy = grid:cellToPixel(nx, ny)
                    love.graphics.setColor(0.95, 0.72, 0.24, 0.55)
                    love.graphics.circle("fill", wx + s / 2, wy + s / 2, 3)
                end
            end

            local col = PATROL_STATE[p.state] or PATROL_STATE.beat
            local wx, wy = grid:cellToPixel(p.x, p.y)
            love.graphics.setColor(col[1], col[2], col[3], 0.95)
            love.graphics.rectangle("fill", wx + 3, wy + 3, s - 6, s - 6, 3)
            love.graphics.setColor(0, 0, 0, 0.55)
            love.graphics.rectangle("line", wx + 3, wy + 3, s - 6, s - 6, 3)

            local kind = p.encounter and p.encounter.kind
            local icon = MarkerIcon[kind]
            if icon then icon(wx + 3, wy + 3, s - 6, s - 6, 1, 1, 1, 1) end

            -- HOW FAR ABOVE THE COMPANY THIS ONE STANDS, in the same pips a seated fight wears. The
            -- readout is keyed by cell everywhere else and a patrol is not on a cell, so without this the
            -- fights that MOVE -- the ones you most need to decide about -- would be the only fights on
            -- the board with no reading at all. Same mark, same place, same meaning.
            local band = self.musterBand and self.musterBand({ x = p.x, y = p.y, encounter = p.encounter })
            local steps = band and Muster.PIPS[band] or 0
            if steps > 0 then
                local pipR = math.max(2.5, s * 0.09)
                local gap = pipR * 2 + 2
                local w = steps * gap - 2
                local cy = wy + s - pipR - 3
                love.graphics.setColor(0.05, 0.05, 0.07, 0.85)
                love.graphics.rectangle("fill", wx + s / 2 - w / 2 - 3, cy - pipR - 1.5,
                    w + 6, pipR * 2 + 3, pipR + 1.5, pipR + 1.5)
                love.graphics.setColor(PIP_COLOR[1], PIP_COLOR[2], PIP_COLOR[3], 1)
                for i = 1, steps do
                    love.graphics.circle("fill", wx + s / 2 - w / 2 + pipR + (i - 1) * gap, cy, pipR)
                end
            end

            -- A slow patrol wears its pace, so "I can get past this one" is readable rather than
            -- learned by being caught.
            if (p.pace or 1) > 1 then
                love.graphics.setColor(0, 0, 0, 0.5)
                love.graphics.rectangle("fill", wx + 5, wy + s - 9, 3, 3)
                love.graphics.rectangle("fill", wx + 10, wy + s - 9, 3, 3)
            end
        end
    end
    love.graphics.setColor(1, 1, 1)
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

-- Track the tile under the pointer, so the HUD can name the fight the player is weighing up
-- (states/game.lua's drawHud). Only a SEEN tile counts -- naming a marker still under fog would hand
-- over the very thing the fog is keeping back.
function OverworldMap:mousemoved(x, y)
    local cx, cy = self.grid:pixelToCell(x + self.camX, y + self.camY)
    local c = self.grid:get(cx, cy)
    self.hoverCell = (c and c.seen) and c or nil
end

-- The encounter the player is weighing up, or nil. Two answers, because there are two ways to be
-- weighing one up and the overworld has no cursor of its own:
--   * with a mouse, whatever marker the pointer is over -- reading ahead, planning a route;
--   * otherwise (keyboard, gamepad), a marker on an ADJACENT tile -- the fight one step away, which
--     is the beat where a pad player actually decides.
-- A cleared stop answers nothing: there is no fight left on it to weigh.
function OverworldMap:hoveredFight()
    local function fightAt(c)
        if not (c and c.seen and c.encounter and not c.cleared) then return nil end
        local kind = c.encounter.kind
        return (kind == "combat" or kind == "elite") and c or nil
    end

    if InputMode.isMouse() then return fightAt(self.hoverCell) end
    for _, d in ipairs({ { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } }) do
        local c = fightAt(self.grid:get(self.px + d[1], self.py + d[2]))
        if c then return c end
    end
    return nil
end

return OverworldMap
