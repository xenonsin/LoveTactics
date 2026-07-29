-- Point EFFECTS on the battle board: the mark a blow leaves where it lands, the bloom of a spell, the
-- rise of a heal, and the projectile that crosses the board to deliver any of it. Owns the one burst
-- shader (shaders/burst.lua), resolves each thing's motif to a shape, and plays each as a short-lived
-- quad centred on a world point. The exact sibling of ui/field_fx.lua -- a field is standing ground, a
-- burst is a thing that happens -- and it reuses ui/motif.lua so the two agree about what fire is.
--
-- One instance per board (ui/battle_map.lua owns it beside self.fields, ticks it from :update and
-- draws it in :draw ABOVE the units and below the readouts):
--   fx:update(dt)
--   fx:draw(map)
--
-- Spawned by the combat animation controller (ui/combat_fx.lua) as it plays out an exchange:
--   fx:strike(x, y, tags, opts)              -- an impact where a blow landed, shape from its tags
--   fx:support(x, y, pattern, opts)          -- motes/sigil for a heal or a friendly cast
--   local dur = fx:flight(fx, fy, tx, ty, tags, opts)  -- a projectile; returns its time in the air, so
--                                            -- the caller can land the blow's whole reaction on arrival
--
-- ---------------------------------------------------------------------------
-- WHY THE CONTROLLER RESOLVES THE MOTIF, NOT THE MODEL
--
-- The model states only what a blow WAS -- it stamps the damage cue with its `tags` and stops there
-- (models/combat.lua). Turning "poison" into a green puff and "pierce" into a stab is a matter of
-- taste that belongs on the view side, next to the shader that draws it. So the model hands over tags;
-- this file reads them through the shared vocabulary (ui/motif.lua) exactly as the tile fields do, and
-- the result is that a Fireball's telegraph, its bolt, its blast and the fire it leaves all resolve
-- from one list with nothing authored to connect them.
--
-- Nothing here touches the GPU at require-time, and the shader compiles LAZILY on first draw under a
-- pcall: a driver that rejects the GLSL latches `failed` and the board simply draws no bursts -- which
-- is the correct degradation, because a burst is decoration over information the hit flash and the
-- damage number already carry. Same tolerance models/sprite.lua gives missing art.
-- ---------------------------------------------------------------------------

local BurstShader = require("shaders.burst")
local Motif = require("ui.motif")

local BurstFx = {}
BurstFx.__index = BurstFx

-- Motif -> burst shape. Eleven shapes for the whole vocabulary: the three ways a body is struck each
-- get their own, every element that has a look gets one, and the ideas that leave no mark (banner,
-- structure) fall through to the default below. Two motifs share a shape on purpose -- holy and light
-- both flare, control and structure both draw a binding sigil -- for the same reason two share a field.
local MOTIF_PATTERN = {
    slash = "slash", pierce = "pierce", impact = "crush",
    fire = "bloom", ice = "shatter", water = "spray", lightning = "bolt",
    wind = "slash", earth = "crush", poison = "spray", acid = "spray",
    dark = "spray", light = "flare", holy = "flare", arcane = "sigil",
    control = "sigil", morale = "motes", structure = "sigil",
}
BurstFx.MOTIF_PATTERN = MOTIF_PATTERN

-- What a blow with no recognised motif looks like: a blunt crush. Every damage cue draws SOMETHING --
-- a hit the player cannot see landed reads as a hit that missed.
BurstFx.DEFAULT_STRIKE = "crush"

-- ...with one exception: a handful of damage kinds leave NO impact mark. These are wounds that tick as
-- a body MOVES or endures, not blows that arrive from somewhere -- Bleed costs blood per tile crossed
-- (data/status/status_bleed.lua), and stamping a fresh crush burst on every step reads as a punch
-- landing out of nowhere each stride. The floating red number and the ground field under the bleeding
-- body already carry the tick; a burst on top is noise. So a blow tagged with any of these draws no
-- strike burst at all -- distinct from DEFAULT_STRIKE above, which is for a real blow whose element we
-- simply do not picture, and which MUST still burst or the hit reads as a miss. The sound and number
-- still play (they are spawned upstream in ui/combat_fx.lua, not here).
BurstFx.MARKLESS = { bleed = true }

-- Per-pattern presentation: how it blends and its default colour. `blend = "add"` for anything made of
-- light (fire, a bolt, a blessing); `"alpha"` for the physical marks (a dust cloud, a gas puff) that
-- sit ON the ground rather than glowing off it. The colour is a fallback -- an elemental burst is
-- tinted by its MOTIF (below) so poison is green and acid is yellow, both drawn by the one `spray`.
local STYLE = {
    slash   = { blend = "add",   color = { 1.00, 1.00, 1.00 }, life = 0.30, radius = 0.85 },
    pierce  = { blend = "add",   color = { 1.00, 0.95, 0.85 }, life = 0.28, radius = 0.80 },
    crush   = { blend = "alpha", color = { 0.82, 0.72, 0.55 }, life = 0.42, radius = 1.00 },
    bloom   = { blend = "add",   color = { 1.00, 0.52, 0.16 }, life = 0.52, radius = 1.15 },
    shatter = { blend = "add",   color = { 0.72, 0.90, 1.00 }, life = 0.42, radius = 1.05 },
    bolt    = { blend = "add",   color = { 0.72, 0.82, 1.00 }, life = 0.34, radius = 1.10 },
    spray   = { blend = "alpha", color = { 0.52, 0.72, 0.32 }, life = 0.55, radius = 1.05 },
    flare   = { blend = "add",   color = { 1.00, 0.92, 0.62 }, life = 0.48, radius = 1.15 },
    sigil   = { blend = "add",   color = { 0.70, 0.52, 1.00 }, life = 0.52, radius = 1.05 },
    motes   = { blend = "add",   color = { 0.60, 0.95, 0.66 }, life = 0.62, radius = 1.00 },
    streak  = { blend = "add",   color = { 1.00, 0.98, 0.90 }, life = 0.30, radius = 0.85 },
}
BurstFx.STYLE = STYLE

-- Motif -> colour, so one shape carries several elements. `spray` is the clearest case: poison green,
-- acid yellow-green, dark violet, plain water blue -- all the same expanding puff, told apart only by
-- this. Matches the tile-field palette (ui/field_fx.lua's STYLE) where the two overlap, so a fire
-- bloom and the flame field it leaves are the same orange.
local MOTIF_COLOR = {
    slash = { 1.00, 1.00, 1.00 }, pierce = { 1.00, 0.95, 0.85 }, impact = { 0.82, 0.72, 0.55 },
    fire = { 1.00, 0.50, 0.15 }, ice = { 0.70, 0.90, 1.00 }, water = { 0.45, 0.66, 0.92 },
    lightning = { 0.66, 0.80, 1.00 }, wind = { 0.82, 0.95, 0.86 }, earth = { 0.55, 0.42, 0.22 },
    poison = { 0.52, 0.78, 0.30 }, acid = { 0.74, 0.92, 0.24 }, dark = { 0.52, 0.36, 0.62 },
    light = { 1.00, 0.95, 0.72 }, holy = { 1.00, 0.90, 0.60 }, arcane = { 0.66, 0.48, 0.96 },
    control = { 0.66, 0.48, 0.96 }, morale = { 0.98, 0.72, 0.30 }, structure = { 0.55, 0.78, 0.95 },
}
BurstFx.MOTIF_COLOR = MOTIF_COLOR

-- Motif -> what the thing crossing the board LOOKS like. Most blows that travel are a thrown or loosed
-- object -- an arrow, a dart, a stone -- and a comet-headed `streak` is what those look like, so the
-- shape tags (slash/pierce/impact) deliberately have no entry and fall through to the default below.
-- The elements that fly as a BALL of themselves get their own body instead, and it is the same body
-- their impact draws, so a Fireball's bolt and its blast are visibly one object arriving. Lightning is
-- absent on purpose: a fork that slides across the board reads as a bug, so a bolt streaks and forks
-- only where it lands.
local FLIGHT_PATTERN = {
    fire = "bloom", ice = "shatter", water = "spray", poison = "spray", acid = "spray",
    dark = "spray", light = "flare", holy = "flare", arcane = "sigil", control = "sigil",
}
BurstFx.FLIGHT_PATTERN = FLIGHT_PATTERN

-- What crosses the board when the blow's motif names no body of its own: the projectile streak.
BurstFx.DEFAULT_FLIGHT = "streak"

-- Projectile pacing. A bolt crosses at a fixed board SPEED (tiles per second) so a long shot really
-- does take longer to arrive than a short one -- distance is the thing a flight exists to show -- but
-- clamped at both ends so a point-blank shot still reads and a full-board shot never dawdles.
BurstFx.FLIGHT_SPEED = 16      -- tiles/second
BurstFx.FLIGHT_MIN = 0.12
BurstFx.FLIGHT_MAX = 0.42

-- A borrowed impact shape is drawn in flight frozen at this point of its life -- past the rise, well
-- before the fall -- so a fireball crossing the board is a fireball at full body rather than one caught
-- mid-birth (every shape's `env` is still at zero on age 0) or mid-death. `streak` ignores age entirely
-- and is unaffected. The borrowed shape also flies a little smaller than it lands, so the arrival still
-- reads as the blow opening up.
BurstFx.FLIGHT_AGE = 0.32
BurstFx.FLIGHT_SCALE = 0.62

-- ---------------------------------------------------------------------------
-- Pure decisions (no love.graphics -- tests/vfx_spec.lua drives these directly)
-- ---------------------------------------------------------------------------

-- Does a blow carrying `tags` leave an impact MARK? False for the markless wounds (Bleed) above, true
-- for everything else -- including a tagless or elementless blow, which still draws the blunt default.
-- :strike consults this and simply does nothing for a markless blow.
function BurstFx.marks(tags)
    for _, t in ipairs(tags or {}) do
        if BurstFx.MARKLESS[t] then return false end
    end
    return true
end

-- The burst shape a blow carrying `tags` draws: its motif's shape, else the blunt default. `explicit`
-- (a caller's chosen pattern) wins, which is how a heal asks for `motes` outright.
function BurstFx.patternFor(tags, explicit)
    if explicit and STYLE[explicit] then return explicit end
    local motif = Motif.of(tags)
    return (motif and MOTIF_PATTERN[motif]) or BurstFx.DEFAULT_STRIKE
end

-- The colour for `tags` at `pattern`: the motif's own colour if it has one, else the pattern's default.
function BurstFx.colorFor(tags, pattern)
    local motif = Motif.of(tags)
    if motif and MOTIF_COLOR[motif] then return MOTIF_COLOR[motif] end
    local style = STYLE[pattern]
    return style and style.color or { 1, 1, 1 }
end

-- Does a blow carrying `tags`, struck across `gap` tiles, actually THROW something across the board?
--
-- The ROUTING tags decide it, not the gap. Motif.of deliberately ignores "melee" and "ranged" because
-- they draw no picture -- but they are precisely the statement of how a blow REACHES a body, which is
-- the one question a projectile answers. So a `melee` weapon never looses anything however far it
-- reaches (the Gathering Bell is a mace with two tiles of swing, and a mace that fires a bolt is
-- nonsense), and a `ranged` one always does.
--
-- Gap is the fallback for the blows that state neither: an ability's own tags are descriptive only
-- ({ "fire", "arcane" }), and a handful of natural weapons -- a blight spitter, a cinder spit -- carry
-- no routing tag either. For those, two tiles of separation IS the evidence that something crossed.
--
-- Note the gap must be measured to the tile the target was STRUCK on, not the one it was knocked to;
-- the caller owns that (ui/combat_fx.lua's struckCells), and getting it wrong is what used to make a
-- mace's own two-tile shove read as two tiles of shooting.
function BurstFx.throwsProjectile(tags, gap)
    for _, t in ipairs(tags or {}) do
        if t == "melee" then return false end
        if t == "ranged" then return true end
    end
    return (gap or 0) >= 2
end

-- The shape a blow carrying `tags` takes while it is in the air: the motif's own flying body, else the
-- default streak. The sibling of patternFor, and read the same way -- so the item doing the attack
-- picks its projectile exactly as it picks its impact.
function BurstFx.flightPatternFor(tags, explicit)
    if explicit and STYLE[explicit] then return explicit end
    local motif = Motif.of(tags)
    return (motif and FLIGHT_PATTERN[motif]) or BurstFx.DEFAULT_FLIGHT
end

-- How long a projectile from (fx, fy) to (tx, ty) spends in the air: distance over speed, clamped.
function BurstFx.flightTime(fx, fy, tx, ty)
    local dist = math.sqrt((tx - fx) ^ 2 + (ty - fy) ^ 2)
    return math.max(BurstFx.FLIGHT_MIN, math.min(BurstFx.FLIGHT_MAX, dist / BurstFx.FLIGHT_SPEED))
end

-- ---------------------------------------------------------------------------
-- Instance
-- ---------------------------------------------------------------------------

function BurstFx.new()
    local self = setmetatable({}, BurstFx)
    self.bursts = {}   -- { x, y, pattern, color, blend, age, life, seed, angle, intensity, radius }
    self.flights = {}  -- { fromX, fromY, toX, toY, t, dur, color, tags, angle }
    return self
end

-- Compile on first draw, once, guarded -- exactly as ui/field_fx.lua does. A failure latches: the
-- board draws no bursts for the rest of the session rather than retrying a compile that will not work.
function BurstFx:shader()
    if self.shaderObj then return self.shaderObj end
    if self.failed then return nil end
    local ok, sh = pcall(love.graphics.newShader, BurstShader.source)
    if not ok or not sh then
        self.failed = true
        return nil
    end
    -- A 1x1 white texture drawn scaled to the burst's quad, so the shader gets texture coords 0..1
    -- across it (love.graphics.rectangle supplies none). Same trick field_fx uses.
    local data = love.image.newImageData(1, 1)
    data:setPixel(0, 0, 1, 1, 1, 1)
    self.px = love.graphics.newImage(data)
    self.shaderObj = sh
    return sh
end

-- ---------------------------------------------------------------------------
-- Spawning (board coordinates -- resolved to pixels at draw time against the map)
-- ---------------------------------------------------------------------------

local function pushBurst(self, x, y, pattern, opts)
    opts = opts or {}
    local style = STYLE[pattern] or STYLE.crush
    self.bursts[#self.bursts + 1] = {
        x = x, y = y, pattern = pattern,
        color = opts.color or style.color,
        blend = style.blend,
        age = 0,
        life = opts.life or style.life,
        radius = opts.radius or style.radius,
        seed = math.random(),
        angle = opts.angle or 0,
        intensity = opts.intensity or 1,
    }
end

-- An impact where a blow landed on cell (x, y). Shape and colour come from the blow's `tags`; `opts`
-- may carry an `angle` (the direction it was struck from, so a slash sweeps and a stab drives the
-- right way) and `lethal` (a killing blow bursts a touch bigger and brighter).
function BurstFx:strike(x, y, tags, opts)
    -- A markless wound (Bleed) leaves no impact burst -- the number and the field say it already.
    if not BurstFx.marks(tags) then return end
    opts = opts or {}
    local pattern = BurstFx.patternFor(tags, opts.pattern)
    local o = {
        color = opts.color or BurstFx.colorFor(tags, pattern),
        angle = opts.angle or 0,
        intensity = opts.intensity or (opts.lethal and 1.3 or 1),
        radius = opts.radius or (opts.lethal and STYLE[pattern].radius * 1.25 or nil),
    }
    pushBurst(self, x, y, pattern, o)
end

-- A supportive flourish (a heal, a friendly cast) on cell (x, y): motes by default, or a named pattern.
function BurstFx:support(x, y, pattern, opts)
    pushBurst(self, x, y, pattern or "motes", opts)
end

-- Launch a projectile from cell (fromX, fromY) toward (toX, toY), shaped and tinted by `tags`: an
-- arrow streaks, a fireball flies as the bloom it will land as (see FLIGHT_PATTERN). Returns the
-- seconds it will spend in the air, so the caller can time the blow's reaction to its arrival
-- (ui/combat_fx.lua defers the hit by exactly this). On arrival the flight spawns the impact burst
-- itself, so the projectile and its blast are one object's whole life.
--
-- WHETHER a blow flies at all is BurstFx.throwsProjectile's decision, made by the caller before it
-- gets here -- this end just draws what it is handed.
function BurstFx:flight(fromX, fromY, toX, toY, tags, opts)
    opts = opts or {}
    local dur = opts.dur or BurstFx.flightTime(fromX, fromY, toX, toY)
    local pattern = BurstFx.flightPatternFor(tags, opts.pattern)
    local style = STYLE[pattern] or STYLE.streak
    self.flights[#self.flights + 1] = {
        fromX = fromX, fromY = fromY, toX = toX, toY = toY,
        t = 0, dur = dur,
        pattern = pattern,
        radius = style.radius * (pattern == BurstFx.DEFAULT_FLIGHT and 1 or BurstFx.FLIGHT_SCALE),
        seed = math.random(),
        color = opts.color or BurstFx.colorFor(tags, pattern),
        tags = tags,
        lethal = opts.lethal,
    }
    return dur
end

-- ---------------------------------------------------------------------------
-- Advance
-- ---------------------------------------------------------------------------

function BurstFx:update(dt)
    dt = dt or 0
    for i = #self.bursts, 1, -1 do
        local b = self.bursts[i]
        b.age = b.age + dt
        if b.age >= b.life then table.remove(self.bursts, i) end
    end
    for i = #self.flights, 1, -1 do
        local f = self.flights[i]
        f.t = f.t + dt
        if f.t >= f.dur then
            -- The bolt lands and is gone. It does NOT burst here: the caller timed a whole beat of
            -- reactions to this exact arrival (ui/combat_fx.lua defers by the duration :flight returned)
            -- and that beat spawns the impact, with the strike angle and the lethality only it knows.
            -- Bursting here as well drew the blast twice, from two owners that had to agree about where
            -- the body was standing -- and did not, once a knockback was in play.
            table.remove(self.flights, i)
        end
    end
end

-- Nothing left to draw and nothing in the air -- lets the board skip the shader bind on a quiet frame.
function BurstFx:idle()
    return #self.bursts == 0 and #self.flights == 0
end

-- ---------------------------------------------------------------------------
-- Draw
-- ---------------------------------------------------------------------------

-- One shader bind for the whole board; uPattern and the blend mode change only when the run moves on
-- to the next family. Bursts first (they are grouped loosely by draw order of spawn), then the flights
-- on top, since a projectile should ride over the ground-level marks.
function BurstFx:draw(map)
    if self:idle() then return end
    local sh = self:shader()
    if not sh then return end

    local size = map.size
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setShader(sh)

    local curBlend
    local function setBlend(blend)
        if blend ~= curBlend then
            curBlend = blend
            love.graphics.setBlendMode(blend == "add" and "add" or "alpha")
        end
    end

    -- One quad, centred on the cell's centre, sized to the burst's radius in tiles. The -1..1 quad the
    -- shader works in maps onto a box `2*radius` tiles across, so a radius of 1 fills roughly one tile
    -- of glow with room to throw past its edges.
    local function drawQuad(cx, cy, radius, pattern, color, alpha, age, seed, angle, aimx, aimy, intensity)
        sh:send("uPattern", BurstShader.PATTERNS[pattern])
        sh:send("uAge", age)
        sh:send("uSeed", seed)
        sh:send("uShape", { intensity or 1, angle or 0 })
        sh:send("uAim", { aimx or 0, aimy or 0 })
        sh:send("uTint", { color[1], color[2], color[3], alpha })
        local r = radius * size
        love.graphics.draw(self.px, cx - r, cy - r, 0, 2 * r, 2 * r)
    end

    for _, b in ipairs(self.bursts) do
        setBlend(b.blend)
        local wx, wy = map:cellToPixel(b.x, b.y)
        local cx, cy = wx + size / 2, wy + size / 2
        drawQuad(cx, cy, b.radius, b.pattern, b.color, 1, b.age / b.life, b.seed,
            b.angle, 0, 0, b.intensity)
    end

    for _, f in ipairs(self.flights) do
        setBlend("add")
        local p = f.dur > 0 and (f.t / f.dur) or 1
        local bx = f.fromX + (f.toX - f.fromX) * p
        local by = f.fromY + (f.toY - f.fromY) * p
        local wx, wy = map:cellToPixel(bx, by)
        local cx, cy = wx + size / 2, wy + size / 2
        -- Fade the projectile in over its first sliver of flight and out over its last, so it neither
        -- pops at the muzzle nor lingers past the impact that replaces it.
        local alpha = math.min(1, p * 8) * math.min(1, (1 - p) * 8 + 0.2)
        -- The travel direction, given both ways: as `uAim` (the streak's own tail) and as the shape
        -- angle every other family reads. A frozen age holds a borrowed body at full bloom (FLIGHT_AGE).
        local dx, dy = f.toX - f.fromX, f.toY - f.fromY
        drawQuad(cx, cy, f.radius, f.pattern, f.color, alpha, BurstFx.FLIGHT_AGE, f.seed,
            math.atan2(dy, dx), dx, dy, 1)
    end

    love.graphics.setShader()
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(1, 1, 1, 1)
end

return BurstFx
