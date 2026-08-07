-- Tile FIELDS: the shader-driven ground every zone, aura, carried status and telegraph on the battle
-- board is painted with. Owns the one shader (shaders/field.lua), decides which CATEGORY each thing
-- reads as, and composites everything standing on a cell instead of letting the last one drawn win.
--
-- One instance per board (ui/battle_map.lua creates it in :new and ticks it from :update):
--   fx:update(dt)
--   fx:draw(map, overlays)                       -- the ground fields, under the interaction overlays
--   fx:drawTelegraph(map, cells, opts)           -- an armed/channelled footprint, over them
--
-- ---------------------------------------------------------------------------
-- FOUR CATEGORIES, ONE VOCABULARY
--
-- The board used to paint by ELEMENT -- flame, rime, rain, spark -- a picture per tag. That read as
-- clutter the moment two zones sat near each other, and it told the player the wrong thing: what a
-- patch of ground is made of matters far less in a tactics game than whether it will help them or hurt
-- them. So a field now reads by what it MEANS to the player, in four looks the shader draws with two
-- shapes (chevrons and crosses -- see shaders/field.lua) that this file colours and points:
--
--   hostile     red chevrons falling      -- ground that damages or debuffs one of your units
--   buff        green chevrons rising     -- a zone that strengthens your side (red, rising, for theirs)
--   heal        blue crosses              -- ground that heals your side (red for theirs)
--
-- The category of a HAZARD comes from its disposition, whether it heals, and whose side owns it -- not
-- from its tags, so nothing in data/hazards had to be told how it looks (Muster is the one exception:
-- it reads friendly by an `fx.valence` override, because its disposition is neutral). The category of a
-- carried STATUS comes from its debuff/restorative nature. A TELEGRAPH takes the category of the cast
-- it previews. All three resolve through FieldFx.CATEGORY, which keeps them agreeing with each other.
--
-- STACKING is the reason the compositing survives. Every field on a cell is collected, ordered by
-- LAYER, and its alpha normalised against the others so two fields read as two rather than as one
-- opaque smear -- alpha-over composites as 1 - product(1 - a), so scaling the sum under a cap is all it
-- takes. The order must be DETERMINISTIC, and combat.hazards is not a stable list (Hazard.tick and
-- Hazard.douse both use table.remove): the sort reads layer, pattern, group, then an ordinal stamped
-- the first frame a field was seen -- never list position -- so a zone expiring cannot make an
-- unrelated tile flicker.
--
-- Nothing here touches the GPU at require-time, and the shader compiles LAZILY on the first draw under
-- a pcall: a driver that rejects the GLSL latches :drawFallback (a flat tinted wash) forever and the
-- board still plays and still reads. Same tolerance models/sprite.lua gives missing art.
-- ---------------------------------------------------------------------------

local FieldShader = require("shaders.field")
local Hazard = require("models.hazard")

local FieldFx = {}
FieldFx.__index = FieldFx

-- Whose eyes the board is drawn for. The player is always the party, so "mine" (blue/green) vs
-- "theirs" (red) is measured against this. Kept as a field rather than a bare literal so a hotseat or
-- spectator view could one day point it elsewhere.
FieldFx.VIEWER = "party"

-- Total alpha one tile's fields may add up to. Below the cap nothing is scaled at all, so a lone field
-- looks exactly as its style declares; above it every field on the cell is scaled by the same factor,
-- which preserves their RATIO -- the loud one stays the loud one.
FieldFx.CAP = 0.88
FieldFx.RAMP = 0.35        -- seconds a newly placed field takes to bloom in
FieldFx.FADE_TICKS = 5     -- remaining ticks over which a field thins out as it runs down
FieldFx.QUIET = 0.55       -- ground fields dim to this while an ability is armed, so the telegraph wins

-- Per-shape presentation: which compositing layer it belongs to, how it blends, and its base density
-- (the alpha a single instance contributes before normalisation). The colour is NOT here -- it is the
-- category's, sent per entry -- so one shape serves every colour it is asked to wear.
local STYLE = {
    chevron = { layer = "field", blend = "alpha", alpha = 0.56 },
    cross   = { layer = "field", blend = "alpha", alpha = 0.64 },
}
FieldFx.STYLE = STYLE

-- Category -> the look it draws: which shape, in what colour, pointed which way (uDir: +1 rising for a
-- boon, -1 falling for a threat, 0 for the directionless cross). THE resolution table, shared by
-- hazards, statuses and telegraphs -- one place that decides what "hostile" looks like, so a hostile
-- hazard, a burning body and an attack's telegraph cannot come to different conclusions.
local CATEGORY = {
    hostile    = { shape = "chevron", color = { 0.749, 0.239, 0.231 }, dir = -1 }, -- red, falling
    buff_ally  = { shape = "chevron", color = { 0.239, 0.608, 0.380 }, dir =  1 }, -- green, rising
    buff_enemy = { shape = "chevron", color = { 0.749, 0.239, 0.231 }, dir =  1 }, -- red, rising
    heal_ally  = { shape = "cross",   color = { 0.275, 0.463, 0.776 }, dir =  0 }, -- blue crosses
    heal_enemy = { shape = "cross",   color = { 0.749, 0.239, 0.231 }, dir =  0 }, -- red crosses
}
FieldFx.CATEGORY = CATEGORY

-- Bottom-to-top compositing order. Everything is one layer today (both shapes paint ON the ground),
-- but the machinery is kept so a shape authored later can slot under or over the rest without a rewrite.
local LAYER_ORDER = { stain = 1, field = 2, mist = 3, glow = 4 }

-- ---------------------------------------------------------------------------
-- Category resolution (pure -- no love.graphics -- tests/field_fx_spec.lua drives these directly)
-- ---------------------------------------------------------------------------

-- Does standing in this hazard heal anybody? Memoised by def (the registry hands out stable
-- singletons), because the honest answer is a dry-run: Hazard.preview fires the zone's onEnter against
-- an allied stand-in and reports the heal and the statuses it grants, and a zone heals if it heals
-- directly or grants a status marked `restorative` (Regeneration). Derived rather than declared, so a
-- Sanctuary and a Renewal Banner are known to be heals without either file saying "I am blue".
local healCache = setmetatable({}, { __mode = "k" })
local function hazardHeals(id, def)
    local cached = healCache[def]
    if cached ~= nil then return cached end
    local result = false
    if id then
        local pv = Hazard.preview(id)
        if pv then
            if (pv.heal or 0) > 0 then result = true end
            for _, s in ipairs(pv.statuses or {}) do
                if s.def and s.def.restorative then result = true break end
            end
        end
    end
    healCache[def] = result
    return result
end

-- The category a HAZARD reads as, from the party's point of view. A friendly zone is a heal or a buff,
-- coloured for whichever side owns it; everything else (hostile, and the neutral zones folded in with
-- it) is a threat on the ground. `fx.valence` lets a def override the disposition its AI uses -- Muster
-- is neutral to the planner but reads friendly to the eye.
function FieldFx.hazardCategory(hazard)
    local def = hazard.def or {}
    local valence = (def.fx and def.fx.valence) or def.disposition
    if valence == "friendly" then
        local mine = Hazard.allied(hazard, FieldFx.VIEWER)
        if hazardHeals(hazard.id, def) then
            return mine and "heal_ally" or "heal_enemy"
        end
        return mine and "buff_ally" or "buff_enemy"
    end
    return "hostile"
end

-- The category a carried STATUS reads as, under a body on `unitSide`. A restorative condition heals (a
-- heal, coloured for whose body it is on), a `debuff` harms (a threat), and anything else is a boon.
function FieldFx.statusCategory(def, unitSide)
    local mine = (unitSide == FieldFx.VIEWER)
    if def.restorative then return mine and "heal_ally" or "heal_enemy" end
    if def.debuff then return "hostile" end
    return mine and "buff_ally" or "buff_enemy"
end

-- The category a TELEGRAPH reads as: an armed cast the player is steering. A support cast previews as a
-- buff (its own side), everything else as a threat. `heals` upgrades a support preview to a heal.
function FieldFx.telegraphCategory(support, heals)
    if support then return heals and "heal_ally" or "buff_ally" end
    return "hostile"
end

-- ---------------------------------------------------------------------------
-- Stacking + edges (pure)
-- ---------------------------------------------------------------------------

local function layerRank(entry)
    local style = STYLE[entry.pattern]
    return (style and LAYER_ORDER[style.layer]) or 9
end

-- Order one tile's fields bottom-up and normalise their alphas under the cap. Returns a NEW list (the
-- entries themselves are shared and their `alpha` is rewritten in place -- they are rebuilt every
-- frame, so there is nothing to preserve). Sorted on layer, then pattern, then group, then the ordinal
-- stamped when the field was first seen -- four stable properties and not one list index, which is what
-- makes the picture immune to combat.hazards being reshuffled by a table.remove somewhere else.
function FieldFx.stack(entries)
    local out = {}
    for i, e in ipairs(entries) do out[i] = e end
    table.sort(out, function(a, b)
        local ra, rb = layerRank(a), layerRank(b)
        if ra ~= rb then return ra < rb end
        if a.pattern ~= b.pattern then return a.pattern < b.pattern end
        if a.group ~= b.group then return tostring(a.group) < tostring(b.group) end
        return (a.ord or 0) < (b.ord or 0)
    end)
    local sum = 0
    for _, e in ipairs(out) do sum = sum + (e.alpha or 0) end
    if sum > FieldFx.CAP then
        local k = FieldFx.CAP / sum
        for _, e in ipairs(out) do e.alpha = (e.alpha or 0) * k end
    end
    return out
end

-- Which of (x, y)'s four sides are the FIELD's boundary: 1 where the neighbour does not carry this same
-- field, 0 where it does. `present` is a set keyed "x,y" holding every cell of one group. Feathering
-- only the 1s is what turns a 3x3 footprint into one patch of ground instead of nine separately-
-- outlined squares.
function FieldFx.edgeMask(present, x, y)
    present = present or {}
    local function boundary(nx, ny) return present[nx .. "," .. ny] and 0 or 1 end
    return boundary(x - 1, y), boundary(x + 1, y), boundary(x, y - 1), boundary(x, y + 1)
end

-- ---------------------------------------------------------------------------
-- Instance
-- ---------------------------------------------------------------------------

function FieldFx.new()
    local self = setmetatable({}, FieldFx)
    self.time = 0
    self.frame = 0
    self.seen = {}   -- field key -> { birth, ord, frame }: birth ramp + stable draw ordinal
    self.ord = 0
    return self
end

function FieldFx:update(dt)
    self.time = self.time + (dt or 0)
    self.frame = self.frame + 1
    -- Mark and sweep: a field nobody collected for a couple of frames is gone (doused, expired, the
    -- battle ended), and its record must go with it or the table grows for the life of the process.
    for key, rec in pairs(self.seen) do
        if self.frame - (rec.frame or 0) > 2 then self.seen[key] = nil end
    end
end

-- Birth time + stable draw ordinal for a field, created on first sight. `key` is the identity of the
-- thing itself -- the runtime hazard table, the status table -- so a zone that is merely REFRESHED
-- (Hazard.place returning the existing one) keeps its ramp instead of blooming again.
function FieldFx:track(key)
    local rec = self.seen[key]
    if not rec then
        self.ord = self.ord + 1
        rec = { birth = self.time, ord = self.ord }
        self.seen[key] = rec
    end
    rec.frame = self.frame
    return rec.birth, rec.ord
end

-- Compile on first draw, once, guarded. A failure latches: the board falls back to the flat wash for
-- the rest of the session rather than retrying a compile that will not start working.
function FieldFx:shader()
    if self.shaderObj then return self.shaderObj end
    if self.failed then return nil end
    local ok, sh = pcall(love.graphics.newShader, FieldShader.source)
    if not ok or not sh then
        self.failed = true
        return nil
    end
    -- A 1x1 white texture, drawn scaled to the tile. The shader needs texture coordinates running
    -- 0..1 across the quad and love.graphics.rectangle supplies none, so the field is an image draw.
    local data = love.image.newImageData(1, 1)
    data:setPixel(0, 0, 1, 1, 1, 1)
    self.px = love.graphics.newImage(data)
    self.shaderObj = sh
    return sh
end

-- ---------------------------------------------------------------------------
-- Collection
-- ---------------------------------------------------------------------------

-- Build this frame's field entries from the overlays, plus the per-group presence sets the edge masks
-- are read from. Returns entries, presence. `map` is the board widget, read only for the slide a
-- CARRIED zone rides (a censer's cloud, a banner's square) so it walks WITH its bearer.
function FieldFx:collect(map, overlays)
    local entries, presence = {}, {}
    local fx = map and map.fx

    local function mark(group, x, y)
        local set = presence[group]
        if not set then set = {}; presence[group] = set end
        set[x .. "," .. y] = true
    end

    -- Hazards: every zone and aura on the board, always visible to both sides (states/battle.lua hands
    -- over the whole live list -- there is no per-side filter like traps have).
    for _, h in ipairs(overlays.hazards or {}) do
        if h.alive then
            local cat = FieldFx.hazardCategory(h)
            local look = CATEGORY[cat]
            local style = STYLE[look.shape]
            local birth, ord = self:track(h)
            -- Blooms in over RAMP, thins out over its last FADE_TICKS -- so a zone about to lapse looks
            -- like one, without opening a tooltip. An owned zone quotes a huge duration and really
            -- answers to its owner's life, so it simply never reaches the fade.
            local ramp = math.min(1, (self.time - birth) / FieldFx.RAMP)
            local decay = math.min(1, math.max(0, (h.remaining or 99) / FieldFx.FADE_TICKS))
            -- A zone a UNIT holds open (a censer's cloud, a banner's rally square) is carried tile-by-
            -- tile in the model the instant its bearer walks (Hazard.carry, resolved up front in
            -- runMove) -- so h.x/h.y is already the destination while the sprite is still sliding in.
            -- Ride the SAME slide the bearer's sprite does (the model tile plus this offset lands the
            -- zone under the feet), so the aura walks with its bearer instead of teleporting ahead of
            -- it. 0 for a zone owned by nothing, or by a body that isn't moving.
            local offX, offY = 0, 0
            if fx and h.owner then offX, offY = fx:slideOffset(h.owner, map.size) end
            entries[#entries + 1] = {
                x = h.x, y = h.y, pattern = look.shape, dir = look.dir,
                group = h.id, ord = ord, color = look.color,
                offX = offX, offY = offY,
                alpha = style.alpha, intensity = 1, fade = ramp * decay,
            }
            mark(h.id, h.x, h.y)
        end
    end

    -- Statuses a unit carries: only the handful whose def declares an `fx` block (battle.lua gates
    -- them). Grouped by status id, so two adjacent burning bodies share one run of chevrons.
    --
    -- Two rules keep a unit from disappearing under its own conditions:
    --
    --  1. THE GROUND SPEAKS FIRST. A field is skipped where a hazard on that same tile already draws
    --     this same category. This matters more than it looks: a ZONE-BOUND status (Regeneration,
    --     Mired) exists only while a zone granting it sits under its bearer -- so its field would always
    --     be a second copy of the zone's own look, on the zone's own tile.
    --
    --  2. AT MOST TWO PER BODY. Beyond that a unit is standing in a stack of its own afflictions and the
    --     badges (ui/status_badge.lua) are the complete read anyway. Taken in first-seen order -- the
    --     ordinal, not list position, so it does not shuffle as statuses come and go.
    local ground = {}
    for _, e in ipairs(entries) do
        ground[e.x .. "," .. e.y .. ":" .. e.pattern .. ":" .. (e.dir or 0)] = true
    end

    local carried, perUnit = {}, {}
    for _, f in ipairs(overlays.unitFields or {}) do
        local def = (f.status and f.status.def) or {}
        local unit = f.unit or {}
        local cat = FieldFx.statusCategory(def, unit.side)
        local look = CATEGORY[cat]
        local key = f.x .. "," .. f.y .. ":" .. look.shape .. ":" .. look.dir
        if not ground[key] then
            ground[key] = true -- and no second status of this category on this tile either
            local _, ord = self:track(f.status)
            carried[#carried + 1] = { f = f, look = look, ord = ord }
        end
    end
    table.sort(carried, function(a, b) return a.ord < b.ord end)
    for _, c in ipairs(carried) do
        local n = (perUnit[c.f.unit] or 0)
        if n < 2 then
            perUnit[c.f.unit] = n + 1
            local f, look, ord = c.f, c.look, c.ord
            local style = STYLE[look.shape]
            local birth = self:track(f.status)
            local ramp = math.min(1, (self.time - birth) / FieldFx.RAMP)
            -- A zone-bound status (`source` set) never ages -- it ends when the ground under it does --
            -- so it must not be read as perpetually about to expire.
            local decay = f.status.source and 1
                or math.min(1, math.max(0, (f.status.remaining or 99) / FieldFx.FADE_TICKS))
            local group = "status:" .. tostring(f.status.id)
            entries[#entries + 1] = {
                x = f.x, y = f.y, pattern = look.shape, dir = look.dir,
                group = group, ord = ord, color = look.color,
                -- The body's in-flight slide, so a carried field walks (and is shoved) WITH its bearer
                -- rather than pinning to the tile the model already moved it to (states/battle.lua).
                offX = f.offX, offY = f.offY,
                -- Quieter than a zone: this is a condition on a body, and the body has to stay the
                -- thing you look at.
                alpha = style.alpha * 0.72, intensity = 0.9, fade = ramp * decay,
            }
            mark(group, f.x, f.y)
        end
    end

    return entries, presence
end

-- ---------------------------------------------------------------------------
-- Draw
-- ---------------------------------------------------------------------------

-- One shader bind for the whole board; uPattern, uDir and the blend mode change only when the sorted
-- run moves on to the next look, so a board costs a handful of state changes rather than one per tile.
function FieldFx:paint(map, ordered, presence, quiet)
    local sh = self.shaderObj
    local size = map.size
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setShader(sh)
    sh:send("uTime", self.time)
    local curPattern, curBlend, curDir
    for _, e in ipairs(ordered) do
        local style = STYLE[e.pattern]
        if e.pattern ~= curPattern then
            curPattern = e.pattern
            sh:send("uPattern", FieldShader.PATTERNS[e.pattern])
        end
        local dir = e.dir or 0
        if dir ~= curDir then
            curDir = dir
            sh:send("uDir", dir)
        end
        if style.blend ~= curBlend then
            curBlend = style.blend
            love.graphics.setBlendMode(curBlend == "add" and "add" or "alpha")
        end
        local l, r, t, b = FieldFx.edgeMask(presence[e.group], e.x, e.y)
        local c = e.color
        sh:send("uCell", { e.x, e.y })
        sh:send("uEdge", { l, r, t, b })
        sh:send("uShape", { e.intensity, e.fade })
        sh:send("uTint", { c[1], c[2], c[3], e.alpha * quiet })
        -- A carried status rides its bearer's in-flight slide (e.offX/offY); ground fields have none.
        local wx, wy = map:cellToPixel(e.x, e.y)
        love.graphics.draw(self.px, wx + (e.offX or 0), wy + (e.offY or 0), 0, size, size)
    end
    love.graphics.setShader()
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(1, 1, 1, 1)
end

-- The ground fields: hazards and carried statuses, drawn in ui/battle_map.lua's old drawHazards slot --
-- under the move/range overlays, the units and the HP bars, which is where scenery belongs.
function FieldFx:draw(map, overlays)
    overlays = overlays or {}
    if not self:shader() then return self:drawFallback(map, overlays) end

    local entries, presence = self:collect(map, overlays)
    if #entries == 0 then return end

    -- Normalise per TILE (that is where the compositing happens), then flatten and re-sort so the whole
    -- board draws one look at a time. Sorting globally cannot disturb the per-tile order: the leading
    -- key is the layer, which is shared by every tile.
    local byCell = {}
    for _, e in ipairs(entries) do
        local k = e.x .. "," .. e.y
        local list = byCell[k]
        if not list then list = {}; byCell[k] = list end
        list[#list + 1] = e
    end
    local ordered = {}
    for _, list in pairs(byCell) do
        for _, e in ipairs(FieldFx.stack(list)) do ordered[#ordered + 1] = e end
    end
    table.sort(ordered, function(a, b)
        local ra, rb = layerRank(a), layerRank(b)
        if ra ~= rb then return ra < rb end
        if a.pattern ~= b.pattern then return a.pattern < b.pattern end
        if (a.dir or 0) ~= (b.dir or 0) then return (a.dir or 0) < (b.dir or 0) end
        if a.group ~= b.group then return tostring(a.group) < tostring(b.group) end
        return (a.ord or 0) < (b.ord or 0)
    end)

    -- An armed ability owns the board while the player is steering it, so the scenery steps back.
    local quiet = (overlays.aoe and #overlays.aoe > 0) and FieldFx.QUIET or 1
    self:paint(map, ordered, presence, quiet)
end

-- A TELEGRAPH: the footprint an armed or channelling ability is about to cover, drawn OVER the
-- interaction overlays rather than under them (ui/battle_map.lua's drawOverlays calls this) and
-- deliberately outside the ground fields' alpha budget -- the thing about to happen must not be dimmed
-- by the ground it is about to happen on.
--
-- `opts` = { category, color, alpha, intensity, group }. Taking the CATEGORY from the armed cast is the
-- whole point: a heal previews as the blue crosses it is about to lay, an attack as the orange chevrons
-- of the threat it leaves -- the promise and the result are visibly the same thing. `color` overrides
-- the category's own (the enemy-reach preview borrows the danger red).
function FieldFx:drawTelegraph(map, cells, opts)
    if not cells or #cells == 0 then return end
    opts = opts or {}
    local look = CATEGORY[opts.category or "hostile"]
    if not (look and STYLE[look.shape]) then return end
    if not self:shader() then return end

    local style = STYLE[look.shape]
    local group = opts.group or ("telegraph:" .. (opts.category or "hostile"))
    local presence = { [group] = {} }
    local ordered = {}
    for _, c in ipairs(cells) do
        presence[group][c.x .. "," .. c.y] = true
        ordered[#ordered + 1] = {
            x = c.x, y = c.y, pattern = look.shape, dir = look.dir, group = group, ord = 0,
            color = opts.color or look.color,
            alpha = opts.alpha or (style.alpha * 0.55),
            intensity = opts.intensity or 0.85,
            fade = 1,
        }
    end
    self:paint(map, ordered, presence, 1)
end

-- ---------------------------------------------------------------------------
-- Fallback
-- ---------------------------------------------------------------------------

-- What the board draws for the machine whose driver refuses the GLSL: a translucent tile wash plus a
-- border, tinted by category (hostile orange / friendly green / heal blue). Loses the shapes, the
-- stacking and the animation, and still says correctly whether the ground helps or hurts.
local FALLBACK = {
    hostile    = { 0.749, 0.239, 0.231 },
    buff_ally  = { 0.239, 0.608, 0.380 },
    buff_enemy = { 0.749, 0.239, 0.231 },
    heal_ally  = { 0.275, 0.463, 0.776 },
    heal_enemy = { 0.749, 0.239, 0.231 },
}

function FieldFx:drawFallback(map, overlays)
    local s = map.size
    for _, h in ipairs(overlays.hazards or {}) do
        if h.alive then
            local wx, wy = map:cellToPixel(h.x, h.y)
            local c = FALLBACK[FieldFx.hazardCategory(h)] or FALLBACK.hostile
            love.graphics.setColor(c[1], c[2], c[3], 0.30)
            love.graphics.rectangle("fill", wx + 2, wy + 2, s - 4, s - 4, 4, 4)
            love.graphics.setColor(c[1], c[2], c[3], 0.80)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", wx + 2, wy + 2, s - 4, s - 4, 4, 4)
            love.graphics.setLineWidth(1)
        end
    end
    love.graphics.setColor(1, 1, 1)
end

return FieldFx
