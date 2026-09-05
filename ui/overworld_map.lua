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
local Overworld = require("models.overworld") -- for the tile name the mass is drawn in (Overworld.BLOCKED)
local InputMode = require("input_mode") -- which device is live, for the hovered-fight readout
local Sprite = require("models.sprite")
local Tileset = require("models.tileset")
local Muster = require("models.muster") -- for BAND -> pip count; the comparison itself is the caller's
local Quest = require("models.quest") -- sponsorOf: which house posted the work standing on a cell
local Encounter = require("models.encounter") -- opensBattle: the one question the combat border asks
local VendorIcons = require("ui.vendor_icons") -- ...and that house's own mark, which is what draws
local Theme = require("ui.theme")

local OverworldMap = {}
OverworldMap.__index = OverworldMap

local DEFAULTS = { axisThreshold = 0.5 }

-- Hold-to-move: after the first step, wait `MOVE_INITIAL` before auto-repeating,
-- then step every `MOVE_REPEAT` seconds while the direction stays held. The pause
-- keeps single taps to one tile; the fast repeat makes long trails quick to walk.
local MOVE_INITIAL = 0.18
local MOVE_REPEAT = 0.05

-- HOW DARK THE MASS IS, and how dark the country beyond the floor is.
--
-- A cell that is not there is drawn in the BIOME'S OWN MATERIAL -- the forest's canopy, the underworld's
-- basalt, the desert's rock -- because that is what the floor was cut out of, and a dungeon whose walls
-- do not say where you are is a dungeon anywhere. That is Dream Quest's board: the same stone all the
-- way to the edge of the screen, with the floor opened out of it.
--
-- It is DIMMED rather than drawn at full, and the reason is the failure this replaced. The first version
-- painted every solid cell one flat near-black, because at full strength the forest's canopy came out
-- BRIGHTER than the ground beside it and the floor read as green fields with brown paths between them --
-- the exact inverse of the truth. Flat black fixed the reading and threw the biome away with it. A dim
-- keeps both: the hue still says forest or basalt or sand, and the value stays under the darkest thing a
-- place can be, so the outline of the floor is never in question.
--
-- HOW DARK, DERIVED PER BIOME RATHER THAN SET. This started as one constant and one constant cannot do
-- it, which is worth writing down because the failure it produces looks like an art problem.
--
-- A biome authors its fill against its floor as a COUNTRY reads: the forest's canopy is darker than its
-- trail, and the tundra's snow drift (0.86, 0.89, 0.93) is far BRIGHTER than its trodden snow, because a
-- bright drift beside a shadowed route is exactly right on a map you cross. Dim every biome by the same
-- 0.45 and the relationship survives -- so the forest reads correctly and the tundra and the desert come
-- out with the mass brighter than the floor, which is the same inversion that made a forest floor look
-- like green fields with brown paths between them.
--
-- So the dim solves for a RELATIONSHIP the biome cannot author its way out of: the mass sits at
-- MASS_BELOW of the darkest a place ever gets, which is a place under unread fog. Every biome keeps its
-- hue -- canopy, basalt, sand, drift -- and none of them can out-brighten the floor. Measured across the
-- eight, the solved dim runs from 0.19 (tundra, a drift that had to come a long way down) to 0.65
-- (underworld, basalt that was already nearly there).
--
-- SURROUND_SCALE is the country past the play area: the same stone a little further off. Close to the
-- mass on purpose -- one continuous material with the floor opened out of it is the reference's whole
-- picture, and what frames the play area is the seam around it rather than a step in value. It was 0.5
-- once and the surround came out darker than the screen's own background, so the floor floated on a
-- black page with no country around it at all, which is the thing this pass exists to fix.
local MASS_BELOW = 0.75
local SURROUND_SCALE = 0.85

-- The two fog tiers, named because the mass is solved against the first of them. They were literals in
-- :drawFog, which was fine while nothing else read them and is not now: the whole point of the
-- derivation below is that the mass sits under the darkest a place can be, so if the veil is deepened
-- here and the mass does not follow, the guarantee is quietly gone. See :drawFog for what each means.
local FOG_UNREAD = 0.66
local FOG_READ = 0.42

-- Perceived brightness. The coefficients are the standard luma weights; what matters here is only that
-- green counts for most of it, which is what a flat average gets wrong on exactly the two biomes that
-- broke the constant.
local function lum(c)
    return 0.2126 * (c[1] or 0) + 0.7152 * (c[2] or 0) + 0.0722 * (c[3] or 0)
end

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
    self.onDoorPosting = opts.onDoorPosting -- a house asks at the door of the room its work stands in
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
    self.hoverX, self.hoverY = nil, nil -- the tile under the mouse, for the HUD's fight readout
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

    -- How far the fog lifts, in STEPS: the place the company stands in and the places beside it. One,
    -- flat, and nothing widens it (models/player.lua's Player.VISION). The game state passes it in and
    -- moves it only for the dark, which takes it to zero.
    self.visionRadius = opts.visionRadius or 1

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
    self.grid:reveal(self.px, self.py, self.visionRadius) -- read the places around the way in
    self:updateCamera()
    self:snapCamera()
    return self
end

-- Build the tileset quads + SpriteBatch, or record that we must fall back to rects.
-- Solve this biome's mass dim: the factor that puts its fill under the darkest a place on it ever gets.
-- Resolved once per floor, in buildTiles, because it depends only on the tileset.
--
--   darkest place = the floor colour seen through unread fog = lum(path) * (1 - FOG_UNREAD)
--   target        = MASS_BELOW of that
--   dim           = target / lum(fill)
--
-- Capped at 1: a biome whose fill is already darker than the target keeps its own colour rather than
-- being brightened up to meet a ceiling it is comfortably under.
-- A plain function on the module rather than a method, so a spec can ask it of every tileset in the
-- game without standing up a widget and a floor to ask through. That matters here: what this returns is
-- a GUARANTEE across eight biomes, and the two that broke the constant it replaced would each have
-- needed a screenshot to catch.
function OverworldMap.massDimFor(tilesetDef)
    local tiles = (tilesetDef and tilesetDef.tiles) or {}
    local fill = tiles[Overworld.BLOCKED] and tiles[Overworld.BLOCKED].color
    local floor = tiles[Overworld.PLACE] and tiles[Overworld.PLACE].color
    if not (fill and floor) then return 0.45 end
    local fillLum = lum(fill)
    if fillLum <= 0.001 then return 1 end
    local target = MASS_BELOW * lum(floor) * (1 - FOG_UNREAD)
    return math.max(0.05, math.min(1, target / fillLum))
end

-- What a place is worth once the fog has had it: the darkest the floor ever reads. Exposed for the same
-- reason -- it is the other half of the comparison the guarantee is about.
function OverworldMap.darkestPlaceLum(tilesetDef)
    local tiles = (tilesetDef and tilesetDef.tiles) or {}
    local floor = tiles[Overworld.PLACE] and tiles[Overworld.PLACE].color
    return floor and lum(floor) * (1 - FOG_UNREAD) or 0
end

function OverworldMap.massLum(tilesetDef)
    local tiles = (tilesetDef and tilesetDef.tiles) or {}
    local fill = tiles[Overworld.BLOCKED] and tiles[Overworld.BLOCKED].color
    return fill and lum(fill) * OverworldMap.massDimFor(tilesetDef) or 0
end

function OverworldMap:solveMassDim()
    return OverworldMap.massDimFor(self.tilesetDef)
end

function OverworldMap:buildTiles()
    self.massDim = self:solveMassDim()
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
                -- The mass the floor is cut out of is dimmed as it is laid, so the art still says which
                -- country this is and the silhouette still reads. See :solveMassDim.
                if self.grid:typeWalkable(c.tile) then
                    self.batch:setColor(1, 1, 1)
                else
                    self.batch:setColor(self.massDim, self.massDim, self.massDim)
                end
                self.batch:add(q, wx, wy, 0, self.tileScale, self.tileScale)
            end
        end
    end
    self.batch:setColor(1, 1, 1)
end

-- THE WHOLE FLOOR IS ON THE SCREEN, so there is no camera left to aim.
--
-- It scrolled for as long as a board was a country -- a 40x40 warren cannot be shown at once and the
-- view had to follow the company across it -- and then it HELD, one chamber at a time, cutting at every
-- doorway, which was the room layer admitting that a floor is a set of discrete places rather than a
-- surface. A grid of places is small enough to draw whole: models/overworld.lua sizes its cells so that
-- every floor, 6x6 or 8x8, fills the same 608-pixel frame.
--
-- What that buys is the thing the minimap was drawn to fake. The plan of the floor, which rooms you
-- have seen and which doors reach them, was a 150-pixel diagram in the corner because the real board
-- could not answer it; now the board IS the plan, and the diagram is gone with the scroll.
--
-- The two names stay because half the widget and both callers in states/game.lua speak them, and what
-- they mean is still true: this sets where the board sits, and :update eases toward it. It simply never
-- changes after the first call.
function OverworldMap:updateCamera()
    local mapW = self.grid.cols * self.grid.size
    local mapH = self.grid.rows * self.grid.size
    self.camTargetX = (mapW - Scale.WIDTH) / 2
    self.camTargetY = (mapH - Scale.HEIGHT) / 2
    self.camX, self.camY = self.camTargetX, self.camTargetY
end


-- Jump the drawn camera straight to its target (no easing) -- used on spawn so the
-- map doesn't pan in from a corner on the first frame.
function OverworldMap:snapCamera()
    self.camX, self.camY = self.camTargetX, self.camTargetY
end

-- ---------------------------------------------------------------------------
-- Movement
-- ---------------------------------------------------------------------------

function OverworldMap:step(dx, dy)
    local nx, ny = self.px + dx, self.py + dy
    if not self.grid:isWalkable(nx, ny, self.keysHeld) then return false end

    -- A HOUSE ASKS BEFORE YOU WALK IN, and it asks from the place next door.
    --
    -- The threshold was a doorway for as long as the floor had walls in it; it is the step itself now.
    -- Accepting marks the work answered and this same step carries the company in; refusing costs
    -- nothing at all, because nothing has moved -- which is what makes it a refusal rather than a toll.
    -- (The version before the rooms stepped ONTO the work and then stepped back off, which read as being
    -- charged for asking.)
    local dest = self.grid:get(nx, ny)
    if dest and dest.encounter and dest.encounter.kind == "objective"
        and dest.encounter.questId and not dest.errandAnswered and self.onDoorPosting then
        if self.onDoorPosting(dest) then return false end
    end

    -- WHICH WAY THE COMPANY CAME IN, kept so a fight opened here knows which side to deploy them on
    -- (Arena's defaultZoneBlock). It was read off the geometry while a place had a doorway; a place has
    -- no doorway, so the step that brought them is the only thing that can answer it.
    self.lastStep = { dx = dx, dy = dy }

    -- About to walk into an un-engaged stop: hand the caller this moment FIRST, before the token moves,
    -- the fog lifts, or :arrive fires anything. states/game.lua autosaves here, so a run saved on the
    -- brink of a fight resumes standing one tile shy of it -- in the overworld, free to open the Loadout
    -- -- rather than being dropped straight back into the battle. Everything the step then grants (a
    -- step ability's forage, the revealed fog) is outside the snapshot, so re-walking it grants it once.
    if self.onApproach and dest and dest.encounter and not dest.cleared then self.onApproach(dest) end
    self.slidePrevX, self.slidePrevY = self.px, self.py -- slide the token from here
    self.slideT = self.slideDur
    self.px, self.py = nx, ny
    -- Lift the fog around the new tile, keeping how much of it was NEW: a step into unmapped country
    -- discovers cells, a step back across known ground discovers none, and the per-step hooks are told
    -- which this was (see onArrive) so an explore-for-coin reward can't be farmed by pacing a cleared map.
    local revealed = self.grid:reveal(self.px, self.py, self.visionRadius)
    if self:arrive(revealed) then return false end
    return true
end

-- WHICH SIDE THE COMPANY ARRIVED ON: "north" | "south" | "east" | "west", or nil before the first step.
--
-- Read off the step that brought them, because a place has no doorway to read it off. Stepping east
-- means arriving from the west side of the place you land in, which is where they should be standing
-- when the fight opens (Arena's defaultZoneBlock).
function OverworldMap:entryEdge()
    local s = self.lastStep
    if not s then return nil end
    if s.dx > 0 then return "west" end
    if s.dx < 0 then return "east" end
    if s.dy > 0 then return "north" end
    if s.dy < 0 then return "south" end
    return nil
end

-- React to landing on a place: pick up keys, trigger encounters. Returns true when it opened an
-- encounter panel, so the caller can halt any in-progress hold-to-move.
--
-- THE PLACE IS THE UNIT AGAIN, and it is the same rule the room layer reached for from the other end. A
-- chamber holding a fight fired it the moment you set foot anywhere in it, because the tile you happened
-- to occupy was not the thing you had chosen -- you had chosen the door. On a grid the cell IS the
-- choice, so walking onto it is the commitment, and a cache standing in the same place cannot be walked
-- over on the way past because there is no way past: it is one cell, and it holds one thing.
function OverworldMap:arrive(revealed)
    local c = self.grid:get(self.px, self.py)
    -- Every landed place: the per-step abilities hook (Kaya's forage, Saber's steps, Gyeom's scouting).
    -- Fired before keys/encounters so a step's reward is banked even where a fight also opens.
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
-- Where cell (cx, cy) is on SCREEN right now, as { x, y, w, h }. The map draws under a camera translate,
-- so a caller that wants to put something of its own on a tile -- a battle board laid on the chamber it
-- is fought in (states/game.lua) -- has to be told where the camera currently has it.
function OverworldMap:cellRect(cx, cy)
    local wx, wy = self.grid:cellToPixel(cx, cy)
    local s = self.grid.size
    return { x = wx - math.floor(self.camX or 0), y = wy - math.floor(self.camY or 0), w = s, h = s }
end

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

-- THE BORDER EVERY FIGHT WEARS, whatever its fill is saying.
--
-- The fill answers "what is this and whose is it", and it has to: an errand wears the house that posted
-- it, the floor's own end wears the boss's gold, an elite wears orange, an outgrown fight goes calm
-- slate. Those are five different colours across five markers that are all the same thing to a player
-- deciding where to walk -- a battle. Nothing on the plate said so, and the one channel that reads at a
-- glance was spent five ways.
--
-- So the BORDER is taken back off the fill and given to the single fact the board is most often asked
-- for. Every stop that opens the arena draws this edge (Encounter.opensBattle), errands and ends
-- included; nothing that does not, draws it. The hostile red is not a new colour -- it is the one every
-- ordinary combat plate has always worn and the one a patrol on its beat already rings, so what changed
-- is that the rest of the fights joined it rather than that anything was invented.
--
-- The fill keeps everything it was saying. A gold plate inside a red edge is still the boss and now also
-- reads as a fight; a calm slate inside a red edge is the outgrown fight, which is the pairing patrols
-- have drawn all along ("beneath your notice" and "still a fight" are not in conflict, and the marker
-- was already asked to say both).
local COMBAT_BORDER = { 0.86, 0.28, 0.22 }

local function markerColor(kind, enc)
    -- THE GOLD IS THE BOSS'S, and nothing else on the board may wear it. The board's own end -- the
    -- guard standing on the way down, the thing the whole day is pointed at -- is the one marker the eye
    -- should find first, and a colour that finds it first is worth more than any other signal here.
    if kind == "objective" then return 0.95, 0.75, 0.20 end
    -- A PIECE OF POSTED WORK WEARS THE HOUSE THAT POSTED IT (ui/vendor_icons.lua). It shared the ends'
    -- gold at first, on the argument that an errand and the floor's own end are both things the day ends
    -- at, with the MARK left to say which house -- and that was a category with one member reasoning
    -- about a board that has seven. A ground carries every house's work at once, so gold stopped meaning
    -- "the end" and started meaning "somebody's work", which is nearly every marker out there; the
    -- boss's own tile had nothing left to be found by. The hue narrows it to a house and the mark
    -- settles it, and the two are learned together on the checklist beside the words (states/game.lua).
    -- Work nobody sponsors keeps the old gold: with no house to name, an end is all it is.
    if kind == "quest" then
        local r, g, b = VendorIcons.color(Quest.sponsorOf(enc and enc.questId))
        if r then return r, g, b end
        return 0.95, 0.75, 0.20
    end
    -- THE WARD wears COLD IRON, and it is the one plate on this board picked by elimination rather than
    -- by meaning. Gold is spent and may not be lent even to the body standing in front of the gold; the
    -- stair's violet belongs to the DOOR and a body is not a door; every warm hue out here already means
    -- either a fight or a gift. What is left is armour, which is at least what a lieutenant holding a
    -- stair is wearing. Banked dark and properly saturated so it is never read as one of the ways out --
    -- the ascent and the crossroads are both pale grey-blues up near white -- and it carries the combat
    -- border neither of those ever does, so steel inside a red ring is only ever this.
    if kind == "ward" then return 0.42, 0.60, 0.82 end
    if kind == "elite" then return 0.95, 0.55, 0.15 end
    if kind == "town" then return 0.85, 0.85, 0.90 end
    if kind == "treasure" then return 0.35, 0.80, 0.55 end
    if kind == "event" then return 0.60, 0.60, 0.95 end   -- a story stop, not a fight
    if kind == "rest" then return 0.45, 0.80, 0.80 end     -- a safe breather
    if kind == "relic_cache" then return 0.80, 0.52, 0.92 end -- a reliquary: a run relic waits inside
    if kind == "shrine" then return 0.88, 0.40, 0.48 end       -- a sin's altar: a Vice for a toll
    if kind == "merchant" then return 0.90, 0.74, 0.32 end      -- a wandering market: goods for gold
    if kind == "crossroads" then return 0.70, 0.72, 0.80 end     -- a branching dilemma: a gamble
    if kind == "ascent" then return 0.72, 0.78, 0.86 end -- the way back up: cold daylight, and the only one
    -- The way DOWN, opened by putting the floor's guard off it. Deliberately the same family as the way
    -- up rather than its own hue: they are one pair, and what tells them apart is which direction the
    -- mark goes -- see MarkerIcon.stair. Banked warmer and darker, so the pair reads as daylight above
    -- and the next circle below without either being mistaken for a fight or a gift.
    if kind == "stair" then return 0.62, 0.58, 0.72 end
    if kind == "pack" then return 0.80, 0.72, 0.42 end -- what you dropped when the company went down
    -- THE THREE HAZARDS share one colour, and that is the point of them: a descent floor's hostile
    -- geography is a category the player learns to recognise ("something is wrong with this square"),
    -- not three things to memorise. The MARK says which; the colour says only that it is not a fight and
    -- not a gift. A sour green-grey, kept well away from the treasure jade and the rest's teal.
    if kind == "dark" or kind == "spinner" or kind == "translation" then
        return 0.45, 0.52, 0.44
    end
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

-- A BARRED SHIELD: the body holding the stair shut. Deliberately NOT the pennant with something added
-- to it -- the pennant says "the end of the floor is here" and this says "and here is what is in the
-- way of it", which is a different sentence and gets a different silhouette. A shield reads as a body
-- under arms at sixteen pixels where a helm or a weapon does not, and the bar across it is the rest of
-- the sentence: nothing goes down until this goes down (states/game.lua reads `wardFor` for the gate).
--
-- The bar is the plate's own colour DARKENED rather than cut out of the shield, so it survives a cleared
-- marker's 0.3 alpha -- a hole would fill with whatever the tile underneath happens to be.
function MarkerIcon.ward(x, y, w, h, r, g, b, a)
    love.graphics.setColor(r, g, b, a)
    -- A heater shield: square across the shoulders, tapering to a point.
    love.graphics.polygon("fill",
        x + w * 0.10, y + h * 0.06,
        x + w * 0.90, y + h * 0.06,
        x + w * 0.90, y + h * 0.52,
        x + w * 0.50, y + h,
        x + w * 0.10, y + h * 0.52)
    love.graphics.setColor(r * 0.30, g * 0.30, b * 0.30, a)
    love.graphics.rectangle("fill", x, y + h * 0.40, w, h * 0.17, 1, 1)
end

-- A POSTED WRIT: the piece of work somebody asked for. A campaign ground's quest, a house's errand, the
-- job lying on a descent floor that opens a shut door -- every end that belongs to a NAME rather than to
-- the map (models/quest.lua's Quest.trip, Descent.floorObjectives). The pennant above stays what it
-- always was: the board's own end, which on a descent floor is the guard standing on the way down.
--
-- Drawn as a sheet with a roll at each end, and the rolls are deliberately WIDER than the sheet: that
-- overhang is the whole silhouette, and it is the one shape on the board that is broader at the top and
-- bottom than through the middle. A scroll drawn as a plain rectangle would read as the event bubble's
-- cousin at sixteen pixels, which is the size this has to survive at.
function MarkerIcon.quest(x, y, w, h, r, g, b, a)
    love.graphics.setColor(r, g, b, a)
    love.graphics.rectangle("fill", x + w * 0.16, y + h * 0.12, w * 0.68, h * 0.76)
    love.graphics.setColor(r * 0.4, g * 0.4, b * 0.4, a)
    love.graphics.rectangle("fill", x, y, w, h * 0.20, 2, 2)
    love.graphics.rectangle("fill", x, y + h * 0.80, w, h * 0.20, 2, 2)
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

-- THE THREE HAZARDS. One colour between them (see markerColor) and three marks, so the category reads
-- at a glance and the particular reads on a look. Each is the thing it does to you, drawn:

-- THE DARK: a lamp flame pinched to nothing. A disc with a bite out of it -- light, most of it gone.
function MarkerIcon.dark(x, y, w, h, r, g, b, a)
    love.graphics.setColor(r, g, b, a)
    love.graphics.arc("fill", x + w / 2, y + h / 2, w * 0.42, math.pi * 0.35, math.pi * 1.65)
end

-- THE TURNING FLOOR: an arrow bent back on itself. Direction, made unreliable.
function MarkerIcon.spinner(x, y, w, h, r, g, b, a)
    love.graphics.setColor(r, g, b, a)
    love.graphics.setLineWidth(math.max(2, w * 0.12))
    love.graphics.arc("line", "open", x + w / 2, y + h / 2, w * 0.34, math.pi * 0.2, math.pi * 1.6)
    love.graphics.setLineWidth(1)
    love.graphics.polygon("fill",
        x + w * 0.52, y + h * 0.06,
        x + w * 0.90, y + h * 0.30,
        x + w * 0.50, y + h * 0.40)
end

-- THE TRANSLATION: two marks and nothing between them. Here, and then there.
function MarkerIcon.translation(x, y, w, h, r, g, b, a)
    love.graphics.setColor(r, g, b, a)
    love.graphics.circle("fill", x + w * 0.22, y + h * 0.74, w * 0.17)
    love.graphics.circle("line", x + w * 0.78, y + h * 0.26, w * 0.17)
end

-- WHAT YOU DROPPED: a bundle, tied. Everything the company was carrying when it went down, in a heap
-- on the tile it fell on -- the one mark on the board that is YOURS rather than the floor's.
function MarkerIcon.pack(x, y, w, h, r, g, b, a)
    love.graphics.setColor(r, g, b, a)
    love.graphics.rectangle("fill", x + w * 0.12, y + h * 0.34, w * 0.76, h * 0.58, w * 0.10)
    love.graphics.setLineWidth(math.max(2, w * 0.10))
    love.graphics.line(x + w * 0.5, y + h * 0.34, x + w * 0.5, y + h * 0.92)
    love.graphics.arc("line", "open", x + w * 0.5, y + h * 0.34, w * 0.22, math.pi, 0)
    love.graphics.setLineWidth(1)
end

-- THE WAY BACK UP: a flight of steps climbing away from the viewer, and an arrow over it. Steps rather
-- than a door, because the one thing this mark has to say at a glance across a fogged board is which
-- DIRECTION it goes -- a descent has stairs at both ends of every floor, and the mark that means "out"
-- must never be read as the one that means "down". The arrow is what settles it.
function MarkerIcon.ascent(x, y, w, h, r, g, b, a)
    love.graphics.setColor(r, g, b, a)
    -- Three treads, each shorter and higher than the last, so the flight reads as going away upward.
    for i = 0, 2 do
        local tw = w * (0.86 - i * 0.20)
        love.graphics.rectangle("fill", x + (w - tw) / 2, y + h * (0.72 - i * 0.20), tw, h * 0.13)
    end
    love.graphics.polygon("fill",
        x + w * 0.5, y,
        x + w * 0.74, y + h * 0.22,
        x + w * 0.26, y + h * 0.22)
end

-- THE WAY DOWN: the same flight of steps, walked the other way, under an arrow that points into it.
-- Drawn as the ascent's mirror on purpose -- a descent has stairs at both ends of every floor and the
-- two marks are one pair, so the treads say "stair" and the direction is the whole of what separates
-- them. Nearest tread widest, so the flight reads as coming toward the viewer and going down.
function MarkerIcon.stair(x, y, w, h, r, g, b, a)
    love.graphics.setColor(r, g, b, a)
    for i = 0, 2 do
        local tw = w * (0.86 - i * 0.20)
        love.graphics.rectangle("fill", x + (w - tw) / 2, y + h * (0.06 + i * 0.20), tw, h * 0.13)
    end
    love.graphics.polygon("fill",
        x + w * 0.5, y + h,
        x + w * 0.74, y + h * 0.78,
        x + w * 0.26, y + h * 0.78)
end

-- A house: a roof over a doored body. A friendly town.
function MarkerIcon.town(x, y, w, h, r, g, b, a)
    love.graphics.setColor(r, g, b, a)
    love.graphics.polygon("fill", x + w / 2, y, x, y + h * 0.45, x + w, y + h * 0.45)
    love.graphics.rectangle("fill", x + w * 0.15, y + h * 0.45, w * 0.7, h * 0.55)
    love.graphics.setColor(r * 0.35, g * 0.35, b * 0.35, a)
    love.graphics.rectangle("fill", x + w * 0.4, y + h * 0.6, w * 0.2, h * 0.4)
end

-- ---------------------------------------------------------------------------
-- THE PLATE EVERY STOP STANDS ON
--
-- A fight that walks and a fight that sits are the same object, and both are drawn by the same three
-- calls -- plate, mark, pips. They used to be drawn twice by hand, in two loops that had drifted a
-- pixel of inset apart, a corner radius apart, and a whole icon size apart: a patrol wore an opaque
-- plate with its mark filling the tile while a seated stop wore a 35% wash with its mark inset by
-- better than a quarter, so the two read as different KINDS of thing when the only difference between
-- them is that one of them moves.
--
-- What a patrol has that a seated stop does not is a STATE -- what it is doing about you -- and that
-- takes the BORDER, which is the one channel a seated stop spends on nothing but its own colour over
-- again. So the wash answers "what is this and how hard is it" identically everywhere on the board,
-- including the outgrown-fight slate a patrol never used to be able to wear, and the ring answers
-- "and it has seen you".
-- ---------------------------------------------------------------------------

local MARKER_INSET = 2       -- px in from the tile edge
local MARKER_RADIUS = 4
local MARKER_WASH = 0.35     -- alpha of the plate's fill, under a full-strength border of the same
local MARKER_ICON_PAD = 0.28 -- share of the tile the mark is inset by, per side

-- The plate: a wash of the stop's own colour under a border. `border` -- the combat red every fight
-- wears, or a patrol's state colour over it -- replaces the fill's own hue and gets a dark backing pass
-- beneath it, the same way the battle board seats its overlay boundaries: an edge that has to carry over
-- ground it shares a hue with cannot be left to luck.
--
-- THE BACKING AND THE WIDTH ARE PART OF THE PROMISE, not decoration on it. "The same border" has to mean
-- the same border -- an ordinary combat plate whose edge was one hairline pixel of its own red while an
-- errand's was two pixels seated on black would be two different marks that happen to share a hue, and
-- the shared thing has to survive being seen at a glance from across the board. So a fight goes through
-- this branch whatever its fill, including the commonest case where the border and the wash are the same
-- colour anyway: that marker got heavier here, and it is the reference the others are matching.
--
-- A stop that is not a fight keeps the old hairline of its own colour, which is now what says so.
local function drawMarkerPlate(wx, wy, s, r, g, b, a, border)
    local px, py = wx + MARKER_INSET, wy + MARKER_INSET
    local pw = s - MARKER_INSET * 2
    love.graphics.setColor(r, g, b, a * MARKER_WASH)
    love.graphics.rectangle("fill", px, py, pw, pw, MARKER_RADIUS, MARKER_RADIUS)
    if border then
        love.graphics.setColor(0, 0, 0, a * 0.55)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", px, py, pw, pw, MARKER_RADIUS, MARKER_RADIUS)
        love.graphics.setColor(border[1], border[2], border[3], a)
        love.graphics.setLineWidth(2)
    else
        love.graphics.setColor(r, g, b, a)
        love.graphics.setLineWidth(1)
    end
    love.graphics.rectangle("line", px, py, pw, pw, MARKER_RADIUS, MARKER_RADIUS)
    love.graphics.setLineWidth(1)
end

-- WHAT THE MARK SAYS, which is not always what the encounter IS.
--
-- A board carries as many ends as the day has work in it and every one of them is stamped `objective`
-- (models/overworld.lua), because to everything downstream -- the arena's cap, the salvage, the payout
-- -- they are one thing: a set-piece. Splitting the KIND would have to be done in the model, where a
-- dozen `kind == "objective"` tests would then quietly stop matching an errand and size it as roadside
-- traffic. So the split is made here, where it is a question about drawing and nothing else.
--
-- The discriminator was already on the cell: a spec that belongs to a piece of work carries the id of
-- that work (`questId`), and the board's own end carries nothing. A campaign ground, where every end IS
-- a quest, therefore draws writs across the board and no pennant at all -- which is the truth about it.
--
-- AND THE SECOND SPLIT IS THE WARD, made here for the same reason and off the same sort of mark. A
-- circle that bars its stair with a body (Descent.GATES' `ward`) seats TWO ends carrying no questId --
-- the guard on the way down and the lieutenant standing in front of her -- and until this test existed
-- they drew the same gold pennant on the same floor with nothing anywhere saying which was which. The
-- ward is not on the checklist either (game:worklist is quests only) and names nothing on hover
-- (hoveredWork wants a questId), so the map was the only surface that could have told them apart and it
-- was drawing them identical. The player found out by walking into one and being told the gate held.
--
-- `wardFor` is the discriminator the model already carries (models/descent.lua), and it is asked FIRST:
-- a ward is stamped `objective` like every other end, so the pennant below would swallow it.
local function markerKind(enc)
    if enc and enc.wardFor then return "ward" end
    if enc and enc.kind == "objective" and enc.questId then return "quest" end
    return enc and enc.kind
end

-- The mark, drawn in white on top of the plate so the SHAPE reads even where two kinds sit close in
-- hue (an event violet against a combat red). An unrecognised kind draws the crossed swords rather
-- than nothing at all: an empty box among marked ones reads as a bug, and a stop with no mark of its
-- own is a fight anyway.
--
-- ONE EXCEPTION, AND IT IS THE WHOLE POINT OF THE GROUND: a piece of posted work draws the mark of the
-- HOUSE THAT POSTED IT (ui/vendor_icons.lua) instead of the generic writ. A day buys a whole ground and
-- every quest standing on it is on the map at once (models/quest.lua's Quest.trip), so a board can be
-- carrying the Bastion's column, the Lodge's hunt and the Undercroft's job at the same time -- three
-- identical scrolls, and no way to tell from the map which shelf the walk over there opens. Which house
-- you are working for is the decision the whole ground is asking, and until now it was the one fact the
-- marker did not carry.
--
-- The PLATE under it carries the same house (markerColor above): the hue narrows the board to one house
-- at arm's length, where a fourteen-pixel shape cannot be read at all, and the mark settles which house
-- once you are looking at it. Two channels, one fact, deliberately -- this is the reverse of the four
-- hazards, which share a colour and split on shape, because a hazard is a category the player must
-- learn as a category and a house is one they already know by name. Work nobody sponsors (the Gate
-- Below) keeps the writ and the old gold, which is what VendorIcons.draw's false return is for.
local function drawMarkerIcon(kind, wx, wy, s, a, enc)
    local pad = s * MARKER_ICON_PAD
    local x, y, box = wx + pad, wy + pad, s - pad * 2
    if kind == "quest"
        and VendorIcons.draw(Quest.sponsorOf(enc and enc.questId), x, y, box, box, 1, 1, 1, a) then
        return
    end
    local icon = MarkerIcon[kind] or MarkerIcon.combat
    icon(x, y, box, box, 1, 1, 1, a)
end

-- How far above the company a stop stands, in pips -- and only for the kinds that comparison is about.
-- A treasure or a camp is not something a muster can be over- or under-matched by, so it draws none.
local function pipSteps(kind, band)
    -- `pack` earns pips for the same reason the other two do: it is a fight, and the one fight a player
    -- has to decide whether to walk back into. See markerColor -- the pack keeps its own colour and mark
    -- so it never reads as ordinary traffic; the pips only say how far over the company it stands.
    if not (kind == "combat" or kind == "elite" or kind == "pack") then return 0 end
    return band and Muster.PIPS[band] or 0
end

-- The pips: one per step above the company, along the plate's bottom edge. None at all when the fight
-- is even or beneath them -- the wash above has already said which of those two it is.
--
-- Sized to be COUNTED, which the old tier pips were not: they were `s * 0.06`, under 2px across at a
-- 32px tile, and three of them could not be told from two. They got away with it only because their
-- colour ALSO encoded the tier (green -> amber -> red), so nobody was counting -- they were reading
-- "red". Now that the count carries a fact of its own, it has to survive being read.
local function drawMarkerPips(wx, wy, s, steps, a)
    if steps <= 0 then return end
    local pipR = math.max(2.5, s * 0.09)
    local gap = pipR * 2 + 2
    local w = steps * gap - 2
    local cy = wy + s - pipR - 2

    -- A dark seat behind the row, because the pips land on the plate's own hostile red and a warning
    -- mark that needs good luck with its background is no warning.
    love.graphics.setColor(0.05, 0.05, 0.07, a * 0.85)
    love.graphics.rectangle("fill", wx + s / 2 - w / 2 - 3, cy - pipR - 1.5,
        w + 6, pipR * 2 + 3, pipR + 1.5, pipR + 1.5)

    love.graphics.setColor(PIP_COLOR[1], PIP_COLOR[2], PIP_COLOR[3], a)
    for i = 1, steps do
        love.graphics.circle("fill", wx + s / 2 - w / 2 + pipR + (i - 1) * gap, cy, pipR)
    end
end

function OverworldMap:draw()
    love.graphics.push()
    love.graphics.translate(-math.floor(self.camX), -math.floor(self.camY))

    -- The country the floor was cut out of, tiled to the edges of the screen, BEFORE the floor itself.
    self:drawSurround()

    -- Tiles.
    if self.tileset then
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(self.batch)
    else
        for y = 1, self.grid.rows do
            for x = 1, self.grid.cols do
                local c = self.grid:get(x, y)
                local solid = not self.grid:typeWalkable(c.tile)
                local def = self.tilesetDef.tiles[c.tile]
                local col = def and def.color or { 0.05, 0.05, 0.06 }
                local d = solid and self.massDim or 1
                local wx, wy = self.grid:cellToPixel(x, y)
                love.graphics.setColor(col[1] * d, col[2] * d, col[3] * d)
                love.graphics.rectangle("fill", wx, wy, self.grid.size, self.grid.size)
            end
        end
    end

    self:drawSeams() -- the hairline between the mass and the floor, which is the silhouette
    self:drawMarkers()
    self:drawFog() -- veils the places whose contents are unread; the silhouette stays legible through it
    self:drawPlayer()

    love.graphics.pop()
end

-- THE COUNTRY BEYOND THE FLOOR, tiled to the edges of the screen in the biome's own material.
--
-- Dream Quest's board is stone all the way out, with the level opened out of it. This is that: the same
-- solid the floor's blocked cells are drawn in, laid on the SAME grid so it reads as one continuous
-- mass, and a little further off (SURROUND_SCALE) so the play area sits in a frame, not on one.
--
-- It is a DRAW, not cells. The grid is the grid; nothing out here is walkable, routable, or reachable by
-- anything that reads `cells`. Making the border real cells would have meant a rectangle of nothing that
-- every placement pass, every BFS and every save had to be taught to ignore -- which is a lot of machine
-- for a picture frame, and the exact kind of thing the old board's margin ring turned out to be.
--
-- Drawn under the camera transform and covering whatever the screen can see, so it stays aligned to the
-- board's own cells at any board size.
function OverworldMap:drawSurround()
    local s = self.grid.size
    local tsDef = self.tilesetDef
    local def = tsDef.tiles[Overworld.BLOCKED]
    local col = (def and def.color) or { 0.05, 0.05, 0.06 }
    local d = self.massDim * SURROUND_SCALE

    -- The visible rectangle, in cell coordinates, rounded outward to whole cells.
    local x0 = math.floor(self.camX / s)
    local y0 = math.floor(self.camY / s)
    local x1 = math.ceil((self.camX + Scale.WIDTH) / s)
    local y1 = math.ceil((self.camY + Scale.HEIGHT) / s)

    local q = self.quads and self.quads[Overworld.BLOCKED]
    love.graphics.setColor(col[1] * d, col[2] * d, col[3] * d)
    for y = y0, y1 do
        for x = x0, x1 do
            -- Inside the board is the board's business; only what is beyond it is drawn here.
            if x < 1 or y < 1 or x > self.grid.cols or y > self.grid.rows then
                -- The board's own mapping, so the mass lines up with the floor's cells instead of
                -- sitting a cell off it: cell 1 starts at the origin, not one cell past it.
                local wx, wy = self.grid:cellToPixel(x, y)
                if q then
                    love.graphics.setColor(d, d, d)
                    love.graphics.draw(self.tileset, q, wx, wy, 0, self.tileScale, self.tileScale)
                    love.graphics.setColor(col[1] * d, col[2] * d, col[3] * d)
                else
                    love.graphics.rectangle("fill", wx, wy, s, s)
                end
                -- ...AND IT IS TILED, not a field. A flat fill of a dark colour reads as black however
                -- carefully the hue was chosen -- the eye has nothing in it to measure. The same seam
                -- the floor's own mass wears (:drawSeams) is what makes this read as courses of stone
                -- rather than as the space the board is floating in, and it does it at a value low
                -- enough to leave the HUD alone.
                love.graphics.setColor(1, 1, 1, 0.05)
                love.graphics.rectangle("line", wx + 0.5, wy + 0.5, s - 1, s - 1)
                love.graphics.setColor(col[1] * d, col[2] * d, col[3] * d)
            end
        end
    end
    love.graphics.setColor(1, 1, 1)
end

-- THE SEAM BETWEEN THE MASS AND THE FLOOR, which is the whole silhouette.
--
-- A hairline on the solid's side of every edge it shares with a place. It is what makes the floor an
-- outline you can read a route across rather than a field of squares -- and it matters most on the frame
-- the company arrives at, where nearly everything is unread and the only thing distinguishing a dim
-- place from the mass beside it is value and hue.
--
-- Over the tiles and UNDER the fog, deliberately: the fog skips solid cells (:drawFog), so the mass is
-- the one thing on the floor whose look never changes. What is not there cannot become better known.
function OverworldMap:drawSeams()
    local s = self.grid.size
    love.graphics.setColor(0.184, 0.196, 0.220, 0.75)
    for y = 1, self.grid.rows do
        for x = 1, self.grid.cols do
            if not self.grid:typeWalkable(self.grid:get(x, y).tile) then
                local wx, wy = self.grid:cellToPixel(x, y)
                love.graphics.rectangle("line", wx + 0.5, wy + 0.5, s - 1, s - 1)
            end
        end
    end

    -- ...AND THE EDGE OF THE FLOOR ITSELF, which is the seam the loop above cannot draw: the mass beyond
    -- the play area is a draw rather than cells, so there is no solid cell out there to hang a line on.
    -- Without it the floor bleeds into the country around it at exactly the places a route runs closest
    -- to the edge. Warmer and stronger than the interior seams, because this one is a FRAME -- it says
    -- how far the floor goes, which is a fact the player needs before the first step.
    local ox, oy = self.grid:cellToPixel(1, 1)
    love.graphics.setColor(0.420, 0.376, 0.278, 0.85)
    love.graphics.rectangle("line", ox - 0.5, oy - 0.5,
        self.grid.cols * s + 1, self.grid.rows * s + 1)
    love.graphics.setColor(1, 1, 1)
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
-- Three tiers: undiscovered tiles are opaque churning mist; discovered tiles outside
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

    -- THE FLOOR PLAN IS NOT A SECRET; WHAT IS STANDING IN IT IS.
    --
    -- The fog used to be opaque over unwalked ground, because on a board you crossed the shape of the
    -- country WAS the discovery -- a junction opened as you reached it, and models/vision.lua cast
    -- shadows so a wall could hide what was behind it. A grid of places has no walls to cast against and
    -- nothing to hide behind: the silhouette is on the map from arrival, and choosing a route is the
    -- whole of what you do with it. Black it out and there is no route to choose.
    --
    -- So an unread place is VEILED rather than covered: you can see the place is there, you cannot see
    -- what is in it (drawMarkers gates on `seen`). Three tiers, all of them see-through:
    --
    --   unread   0.66 -- a place you know is there and have never stood beside
    --   read     0.42 -- read once and remembered; its marker draws, the ground is dim
    --   lit        -- adjacent right now
    --
    -- THE UNREAD TIER IS SET BY THE WORST CASE, WHICH IS ARRIVAL. It was 0.78, tuned by eye on a 6x6
    -- floor where a step of sight lights a good share of the board. On a 10x10 with one-step sight
    -- (Player.VISION) about ninety-five per cent of the floor is unread when the company walks in, so
    -- that tier IS the picture -- and at 0.78 a place kept so little of its own colour that the void
    -- beside it was barely a different black. Reading a route across the plan is the whole of what the
    -- fog leaves the player to do; if the plan is not crisp on the frame they arrive at, it does not
    -- work at all.
    --
    -- A cell that is NOT THERE takes no fog at all. It is already the dark tile, and veiling it would
    -- make the floor's outline the one thing on the board the player has to squint at.
    -- :lit is the method, not a copy of it. It read `inVision` directly here for as long as the marker
    -- pass had its own reason to ask the same question; the marker pass stopped asking when fights
    -- became remembered, which would have left the method with no caller and this closure as a second
    -- definition of the same idea. One of them had to go, and the one with a spec on it stays.
    local function lit(_, x, y)
        return self:lit(x, y) ~= nil
    end
    local function solid(c)
        return not self.grid:typeWalkable(c.tile)
    end

    if not sh then
        for y = 1, self.grid.rows do
            for x = 1, self.grid.cols do
                local c = self.grid:get(x, y)
                local wx, wy = self.grid:cellToPixel(x, y)
                if solid(c) then -- not a place: it is already dark, and its outline is the floor plan
                elseif not c.seen then
                    love.graphics.setColor(0.02, 0.02, 0.03, FOG_UNREAD)
                    love.graphics.rectangle("fill", wx, wy, s, s)
                elseif not lit(c, x, y) then
                    love.graphics.setColor(0.02, 0.02, 0.03, FOG_READ)
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
            local alpha, breathe
            if solid(c) then -- not a place: no fog, so the floor's outline reads at a glance
            elseif not c.seen then
                alpha, breathe = FOG_UNREAD, 0.03 -- a place you know is there and have not stood beside
            elseif not lit(c, x, y) then
                alpha, breathe = FOG_READ, 0.06
            end
            if alpha then
                local wx, wy = self.grid:cellToPixel(x, y)
                sh:send("uCell", { x, y })
                sh:send("uAlpha", alpha)
                sh:send("uBreathe", breathe)
                love.graphics.draw(self.fogPx, wx, wy, 0, s, s)
            end
        end
    end
    love.graphics.setShader()
    love.graphics.setColor(1, 1, 1)
end

-- EVERYTHING FOUND IS REMEMBERED, FIGHTS INCLUDED. Once a place has been read, what is standing in it
-- stays on the map: mapped-but-dark ground shows the mark you found there. That is what makes a map
-- worth having, and it is what lets a detour be planned from across the floor instead of stumbled into
-- twice.
--
-- THIS WAS TWO RULES, AND THE SPLIT DIED WITH THE PATROLS. A landmark -- a gate, a key, a cache, the
-- objective's pennant, a camp, a shop -- was a fact about the country and was kept; a LIVE FIGHT was a
-- BODY, drew only on a tile lit right now, and went out with the light. The argument was that where a
-- fight is standing is not something a map can honestly know, and a board that listed every one of them
-- ahead would answer the question the fog was asked for.
--
-- That was true of a board where fights WALKED. A share of every board's combat lifted off its cell onto
-- a beat and moved a tile for every step the company took, so a remembered fight marker really would
-- have been a lie about a body that had since gone somewhere else -- and the rule had to cover the
-- seated fights too, or the drawn ones would have told you which was which.
--
-- Nothing on a floor moves any more. A fight stands in a place, and a place is exactly the kind of thing
-- a map remembers. Holding fights to the old rule with the beats gone did not preserve a mystery, it
-- just made the one mark the player most needs for routing the one mark that would not stay put --
-- which on a floor a fifth full, read one step at a time, is most of what there is to route around.
--
-- What still hides a fight is the fog itself: an unread place shows nothing, and there are a great many
-- of them. Discovery is the cost; memory is the reward for having paid it.
--
-- `pathTo`, which routes across mapped ground, is gated by neither -- you can walk home through the
-- dark, past what you remember and past what you cannot see.

-- A live fight: the one mark that is a body rather than a place. Shared by the marker pass and by the
-- hovered-fight readout, so what is drawn and what is named can never disagree about what a fight is.
local function isFight(c)
    local e = c and c.encounter
    -- A guarded pack counts, and only a guarded one: `composition` is what says something is standing
    -- there (models/descent.lua's Descent.packGuard). A pile left before the guard existed is still a
    -- pickup, and drawing a hovered-fight readout over it would name a fight that never opens.
    if e and e.kind == "pack" then return not c.cleared and e.composition ~= nil end
    return e ~= nil and not c.cleared and (e.kind == "combat" or e.kind == "elite")
end

-- The cell at (x, y) if it has been discovered, or nil. The memory test: every landmark hangs off it,
-- and so does the fog's first tier, so a mark can never surface under mist that is hiding its tile.
function OverworldMap:mapped(x, y)
    local c = self.grid:get(x, y)
    if not (c and c.seen) then return nil end
    return c
end

-- The cell at (x, y) if it is lit RIGHT NOW -- discovered *and* inside the current vision disc -- or
-- nil. The test every fight asks, so what the fog veils and what a fight marker skips can never drift
-- apart: it is the same `inVision` reveal itself lit the tile with.
function OverworldMap:lit(x, y)
    local c = self:mapped(x, y)
    if not c then return nil end
    if not self.grid:inVision(self.px, self.py, x, y, self.visionRadius) then return nil end
    return c
end

-- The cell at (x, y) whose encounter marker should draw, or nil: any stop that has been found. One
-- function rather than a condition spelled out in the draw loop, because it is the rule above and a
-- spec has to be able to ask it.
--
-- It carried a second clause -- `if isFight(c) and not self:lit(x, y) then return nil end` -- and the
-- note above says why it is gone.
function OverworldMap:markedStop(x, y)
    local c = self:mapped(x, y)
    if not (c and c.encounter) then return nil end
    return c
end

-- Walks the whole board, as the fog pass does: the landmarks it keeps can stand anywhere the player has
-- ever been, so there is no window to shrink this to.
function OverworldMap:drawMarkers()
    local s = self.grid.size
    love.graphics.setFont(self.font)
    for y = 1, self.grid.rows do
        for x = 1, self.grid.cols do
            local c = self:mapped(x, y)
            if c then
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
                -- letter, so it never reads as another kind of encounter -- it costs no fight and opens
                -- no panel, it is simply picked up on arrival. Copper against the key's gold: the same
                -- "walk here and take it" family, a different thing in it. Sized and darkly outlined to
                -- carry at 32px over a pale trail, because the tile it stands on may be lit for one step
                -- of a walk past the mouth of a spur, and a detour has to be decidable in that step.
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

                if self:markedStop(x, y) then
                    local kind = markerKind(c.encounter)
                    local r, g, b = markerColor(kind, c.encounter)
                    -- How this fight stands against the company, asked once and spent twice below: on
                    -- the box colour and on the pips. Nil for a stop there is no comparison to make
                    -- about -- a treasure, a rest, an escort fight the muster cannot price -- which
                    -- keeps its ordinary hostile colour and draws no pips, as before any of this existed.
                    local band = self.musterBand and self.musterBand(c) or nil
                    if band == "beneath" then r, g, b = CALM_MARKER[1], CALM_MARKER[2], CALM_MARKER[3] end
                    local a = c.cleared and 0.3 or 1
                    -- A seated stop has no STATE to report -- that is the patrols' business -- but it
                    -- answers the same first question they do, and answers it on the same channel: if
                    -- walking here opens the arena, the plate wears the combat edge. Asked through
                    -- Encounter.opensBattle rather than by listing kinds, so the border cannot promise a
                    -- fight states/game.lua would decline to run. See COMBAT_BORDER.
                    drawMarkerPlate(wx, wy, s, r, g, b, a,
                        Encounter.opensBattle(c.encounter) and COMBAT_BORDER or nil)
                    drawMarkerIcon(kind, wx, wy, s, a, c.encounter)
                    drawMarkerPips(wx, wy, s, pipSteps(kind, band), a)
                    love.graphics.setColor(1, 1, 1)
                end
            end
        end
    end
end

-- A patrol's state, as the marker's BORDER. Beat keeps the hostile red every fight has always worn;
-- Alert is the warm gold the board already uses for "live, act now"; Return is a cool slate.
--
-- It is the border rather than the fill because the fill is spoken for: a patrol is a fight like any
-- other and its wash has to say how it stands against the company, in the one colour language the
-- seated stops already speak. Two facts, two channels -- what it is, and what it is doing.
--
-- The slate is deliberately DARKER than the outgrown-fight slate (CALM_MARKER): those two must not be
-- confused, because one means "beneath your notice" and the other means "has just lost you and is
-- walking home", which are opposite invitations. Now that a patrol can wear both at once -- a calm
-- wash under a returning ring -- the separation matters more, not less.
--
-- `beat` IS the combat border (COMBAT_BORDER, not a second copy of the same three numbers): a patrol
-- doing nothing about you is a fight wearing exactly the edge every other fight wears, and the two
-- states that differ are the two that have something extra to say. That is also why a patrol needs no
-- special case in the border rule below -- its ring already resolves to the right colour by default.
local PATROL_STATE = {
    beat = COMBAT_BORDER,
    alert = { 0.95, 0.72, 0.24 },
    return_ = { 0.42, 0.48, 0.55 },
}

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

-- Track the place under the pointer, so the HUD can name the fight the player is weighing up
-- (states/game.lua's drawHud). A FOUND place counts, lit or not -- the readout has to answer wherever a
-- marker is drawn, or the pointer names a thing on one cell and goes silent on the identical thing one
-- step further out. What it must never do is answer where nothing is drawn, which would turn the
-- pointer into a probe you sweep across the dark; `mapped` is exactly the test the marker pass uses, so
-- the two cannot drift.
--
-- The pointer's CELL COORDINATES are stored rather than the cell it resolved to, which mattered while a
-- marker could go out from under a stationary mouse and costs nothing now.
function OverworldMap:mousemoved(x, y)
    self.hoverX, self.hoverY = self.grid:pixelToCell(x + self.camX, y + self.camY)
end

-- The encounter the player is weighing up, or nil. Two answers, because there are two ways to be
-- weighing one up and the overworld has no cursor of its own:
--   * with a mouse, whatever marker the pointer is over -- reading ahead, planning a route;
--   * otherwise (keyboard, gamepad), a marker on an ADJACENT tile -- the fight one step away, which
--     is the beat where a pad player actually decides.
-- A cleared stop answers nothing: there is no fight left on it to weigh.
function OverworldMap:hoveredFight()
    local function fightAt(c)
        return isFight(c) and c or nil
    end

    if InputMode.isMouse() then return fightAt(self:mapped(self.hoverX, self.hoverY)) end
    for _, d in ipairs({ { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } }) do
        local c = fightAt(self:mapped(self.px + d[1], self.py + d[2]))
        if c then return c end
    end
    return nil
end

-- THE PIECE OF POSTED WORK the player is weighing up, or nil. The same two answers hoveredFight gives
-- and for the same two reasons, over a different set of stops.
--
-- A SEPARATE QUESTION RATHER THAN A WIDER `isFight`, and the reason is in that function's own note: it
-- is shared with the marker pass, so widening it to admit an objective would change what the board
-- DRAWS as a live fight, not just what the HUD names. An end is a set-piece and reads as one; what it
-- shares with a roadside fight is only that the player stands next to it deciding.
--
-- ONLY WORK SOMEBODY POSTED (`questId`), which is the same discriminator markerKind splits on: the
-- board's own end -- the stair guardian -- carries none, and it has nothing to say that the readout
-- above the map does not already say. What this is FOR is the first-clear bonus on a house's errand,
-- which is a figure the player weighs before committing and which nothing on the board could carry.
function OverworldMap:hoveredWork()
    local function workAt(c)
        local e = c and c.encounter
        if not (e and e.kind == "objective" and e.questId and not c.cleared) then return nil end
        return c
    end

    if InputMode.isMouse() then return workAt(self:mapped(self.hoverX, self.hoverY)) end
    for _, d in ipairs({ { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } }) do
        local c = workAt(self:mapped(self.px + d[1], self.py + d[2]))
        if c then return c end
    end
    return nil
end

return OverworldMap
