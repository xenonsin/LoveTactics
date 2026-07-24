-- Tile FIELDS: the shader-driven ground every zone, aura, carried status and telegraph on the battle
-- board is painted with. Owns the one shader (shaders/field.lua), decides which of its ten patterns
-- each thing resolves to, and composites everything standing on a cell instead of letting the last
-- one drawn win.
--
-- One instance per board (ui/battle_map.lua creates it in :new and ticks it from :update):
--   fx:update(dt)
--   fx:draw(map, overlays)                       -- the ground fields, under the interaction overlays
--   fx:drawTelegraph(map, cells, opts)           -- an armed/channelled footprint, over them
--
-- ---------------------------------------------------------------------------
-- THREE SOURCES, ONE VOCABULARY
--
-- A field can come from a hazard (fire, rain, a Sanctuary, the square a banner holds -- see
-- models/hazard.lua, where zones and auras are already one concept), from a STATUS a unit carries
-- (a burning body should stand in flame), or from a TELEGRAPH (the footprint an armed ability is
-- about to cover). All three resolve their pattern through the same TAG_PATTERN table, which is
-- what keeps the vocabulary honest: a Fire hazard, a Burning unit and a Fireball's blast preview
-- all reach `flame` off the same "fire" tag, with nothing authored anywhere to say so.
--
-- STACKING is the reason this exists at all. The board's old picture drew one flat rect per hazard,
-- so rain drifting over a Sanctuary simply covered it. Here every field on a cell is collected,
-- ordered by LAYER (stain under the body under the mist under the glow), and its alpha normalised
-- against the others so three fields read as three rather than as one opaque smear -- alpha-over
-- composites as 1 - product(1 - a), so scaling the sum under a cap is all it takes.
--
-- The order must be DETERMINISTIC, and combat.hazards is not a stable list: Hazard.tick and
-- Hazard.douse both use table.remove, which reshuffles every index after the one they drop. So the
-- sort never touches list position -- it reads layer, then pattern, then group, then an ordinal
-- stamped the first frame a field was seen. Two zones that expire in the wrong order cannot make an
-- unrelated tile flicker.
--
-- Nothing here touches the GPU at require-time, and the shader is compiled LAZILY on the first draw
-- under a pcall: a driver that rejects the GLSL latches :drawFallback (the old tinted wash) forever
-- and the board still plays and still reads. Same tolerance models/sprite.lua gives missing art.
-- ---------------------------------------------------------------------------

local FieldShader = require("shaders.field")
local Motif = require("ui.motif")

local FieldFx = {}
FieldFx.__index = FieldFx

-- Total alpha one tile's fields may add up to. Below the cap nothing is scaled at all, so a lone
-- field looks exactly as its style declares; above it every field on the cell is scaled by the same
-- factor, which preserves their RATIO -- the loud one stays the loud one.
FieldFx.CAP = 0.88
FieldFx.RAMP = 0.35        -- seconds a newly placed field takes to bloom in
FieldFx.FADE_TICKS = 5     -- remaining ticks over which a field thins out as it runs down
FieldFx.QUIET = 0.55       -- ground fields dim to this while an ability is armed, so the telegraph wins

-- Bottom-to-top compositing order. A stain is IN the ground, a field sits ON it, a mist hangs above
-- it and a glow is light thrown over all three -- which is also the order they have to draw in for
-- any two of them to read as two.
local LAYER_ORDER = { stain = 1, field = 2, mist = 3, glow = 4 }

-- Per-pattern presentation: which layer it belongs to, how it blends, its default tint, and its base
-- density (the alpha a single instance contributes before normalisation). A blueprint's own `fx`
-- block overrides the tint and scales the density; the layer and blend are the pattern's own, so a
-- def cannot author itself out of the compositing order.
local STYLE = {
    flame  = { layer = "field", blend = "alpha", color = { 1.00, 0.45, 0.13 }, alpha = 0.62 },
    smoke  = { layer = "mist",  blend = "alpha", color = { 0.42, 0.56, 0.28 }, alpha = 0.72 },
    rime   = { layer = "field", blend = "alpha", color = { 0.68, 0.90, 1.00 }, alpha = 0.62 },
    rain   = { layer = "mist",  blend = "alpha", color = { 0.45, 0.66, 0.92 }, alpha = 0.58 },
    spark  = { layer = "glow",  blend = "add",   color = { 0.62, 0.76, 1.00 }, alpha = 0.62 },
    mire   = { layer = "stain", blend = "alpha", color = { 0.34, 0.26, 0.12 }, alpha = 0.72 },
    rune   = { layer = "stain", blend = "alpha", color = { 0.66, 0.48, 0.96 }, alpha = 0.55 },
    halo   = { layer = "glow",  blend = "add",   color = { 1.00, 0.90, 0.60 }, alpha = 0.44 },
    banner = { layer = "glow",  blend = "add",   color = { 0.98, 0.72, 0.30 }, alpha = 0.46 },
    ward   = { layer = "field", blend = "alpha", color = { 0.55, 0.78, 0.95 }, alpha = 0.50 },
}
FieldFx.STYLE = STYLE

-- Motif -> pattern: which GROUND each element leaves. Ten pictures for fourteen motifs, because two
-- pairs genuinely share one: holy and light both pool as a halo, a banner and the morale it raises are
-- one square of cloth. The motifs with no entry (slash, pierce, impact, wind, acid) leave no ground at
-- all -- a sword stroke is a thing that happens, not a thing that stays -- and Motif.tagTable drops
-- them rather than making this file invent a field for them.
local MOTIF_PATTERN = {
    fire = "flame",
    poison = "smoke", dark = "smoke",
    ice = "rime",
    water = "rain",
    lightning = "spark",
    earth = "mire",
    arcane = "rune", control = "rune",
    holy = "halo", light = "halo",
    banner = "banner", morale = "banner",
    structure = "ward",
}
FieldFx.MOTIF_PATTERN = MOTIF_PATTERN

-- Tag -> pattern. THE resolution rule, shared by hazards, statuses and telegraphs alike -- and now
-- DERIVED from the one motif vocabulary (ui/motif.lua) that the impact bursts and sprite modes read
-- too, so a Fireball's ground and a Fireball's blast cannot come to different conclusions about what
-- fire is. Read in the order a def lists its tags, so a hazard tagged { "water", "conductable" } takes
-- `rain` and one tagged { "lightning", "conductable" } takes `spark` -- the descriptive tag leads, the
-- mechanical one trails, and neither def had to say a word about how it looks.
local TAG_PATTERN = Motif.tagTable(MOTIF_PATTERN)
FieldFx.TAG_PATTERN = TAG_PATTERN

-- Last resort for a zone whose tags say nothing this table knows: fall back on what the enemy AI
-- already reads off it. Never reached by any shipped hazard (tests/field_fx_spec.lua asserts all 24
-- resolve by tag), but a new blueprint with an unfamiliar tag gets a picture rather than nothing.
local DISPOSITION_PATTERN = { hostile = "smoke", friendly = "halo", neutral = "smoke" }

-- ---------------------------------------------------------------------------
-- Pure decisions (no love.graphics -- tests/field_fx_spec.lua drives these directly)
-- ---------------------------------------------------------------------------

-- The pattern name for a thing carrying `tags`, or nil if nothing resolves. An `explicit` name (a
-- def's `fx.pattern`) wins outright, which is how a def takes a family its tags don't imply --
-- Halting Ground is tagged "control" and wants the rune circle, Darkness is tagged "dark" and wants
-- smoke in a colour no other smoke uses.
function FieldFx.patternFor(tags, explicit)
    if explicit and STYLE[explicit] then return explicit end
    for _, t in ipairs(tags or {}) do
        local p = TAG_PATTERN[t]
        if p then return p end
    end
    return nil
end

-- The pattern for a HAZARD blueprint: its tags, then its disposition as a backstop.
function FieldFx.hazardPattern(def)
    def = def or {}
    return FieldFx.patternFor(def.tags, def.fx and def.fx.pattern)
        or DISPOSITION_PATTERN[def.disposition]
        or "smoke"
end

local function layerRank(entry)
    local style = STYLE[entry.pattern]
    return (style and LAYER_ORDER[style.layer]) or 9
end

-- Order one tile's fields bottom-up and normalise their alphas under the cap. Returns a NEW list
-- (the entries themselves are shared and their `alpha` is rewritten in place -- they are rebuilt
-- every frame, so there is nothing to preserve).
--
-- Sorted on layer, then pattern, then group, then the ordinal stamped when the field was first seen
-- -- four stable properties and not one list index, which is what makes the picture immune to
-- combat.hazards being reshuffled by a table.remove somewhere else entirely.
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

-- Which of (x, y)'s four sides are the FIELD's boundary: 1 where the neighbour does not carry this
-- same field, 0 where it does. `present` is a set keyed "x,y" holding every cell of one group.
-- Feathering only the 1s is what turns a 3x3 footprint into one patch of ground instead of nine
-- separately-outlined squares.
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

-- Build this frame's field entries from the overlays, plus the per-group presence sets the edge
-- masks are read from. Returns entries, presence.
function FieldFx:collect(overlays)
    local entries, presence = {}, {}

    local function mark(group, x, y)
        local set = presence[group]
        if not set then set = {}; presence[group] = set end
        set[x .. "," .. y] = true
    end

    -- Hazards: every zone and aura on the board, always visible to both sides (states/battle.lua
    -- hands over the whole live list -- there is no per-side filter like traps have).
    for _, h in ipairs(overlays.hazards or {}) do
        if h.alive then
            local def = h.def or {}
            local pat = FieldFx.hazardPattern(def)
            local style = STYLE[pat]
            local fx = def.fx or {}
            local birth, ord = self:track(h)
            -- Blooms in over RAMP, thins out over its last FADE_TICKS -- so a fire about to gutter
            -- out looks like one, without opening a tooltip. An owned zone quotes a huge duration
            -- and really answers to its owner's life, so it simply never reaches the fade.
            local ramp = math.min(1, (self.time - birth) / FieldFx.RAMP)
            local decay = math.min(1, math.max(0, (h.remaining or 99) / FieldFx.FADE_TICKS))
            entries[#entries + 1] = {
                x = h.x, y = h.y, pattern = pat, group = h.id, ord = ord,
                color = fx.color or style.color,
                alpha = style.alpha * (fx.density or 1),
                intensity = fx.intensity or 1,
                fade = ramp * decay,
            }
            mark(h.id, h.x, h.y)
        end
    end

    -- Statuses a unit carries: only the handful whose def declares an `fx` block. Grouped by status
    -- id, so two adjacent burning bodies share one sheet of flame.
    --
    -- Two rules keep a unit from disappearing under its own conditions:
    --
    --  1. THE GROUND SPEAKS FIRST. A field is skipped where a hazard on that same tile already draws
    --     the same pattern. This matters more than it looks: a ZONE-BOUND status (Regeneration,
    --     Mired) exists only while a zone granting it sits under its bearer -- so its field would
    --     always be a second copy of the Sanctuary's own halo, on the Sanctuary's own tile. The
    --     mechanic that makes those statuses zone-bound is the same one that makes their field
    --     redundant, and one check covers both.
    --
    --  2. AT MOST TWO PER BODY. Beyond that a unit is standing in a stack of its own afflictions and
    --     the badges (ui/status_badge.lua) are the complete read anyway. Taken in first-seen order --
    --     the ordinal, not list position, so it does not shuffle as statuses come and go.
    local ground = {}
    for _, e in ipairs(entries) do ground[e.x .. "," .. e.y .. ":" .. e.pattern] = true end

    local carried, perUnit = {}, {}
    for _, f in ipairs(overlays.unitFields or {}) do
        local def = (f.status and f.status.def) or {}
        local fx = def.fx
        local pat = fx and FieldFx.patternFor(nil, fx.pattern)
        local key = pat and (f.x .. "," .. f.y .. ":" .. pat)
        if pat and not ground[key] then
            ground[key] = true -- and no second status of this pattern on this tile either
            local _, ord = self:track(f.status)
            carried[#carried + 1] = { f = f, pat = pat, fx = fx, def = def, ord = ord }
        end
    end
    table.sort(carried, function(a, b) return a.ord < b.ord end)
    for _, c in ipairs(carried) do
        local n = (perUnit[c.f.unit] or 0)
        if n < 2 then
            perUnit[c.f.unit] = n + 1
            local f, pat, fx, def, ord = c.f, c.pat, c.fx, c.def, c.ord
            local style = STYLE[pat]
            local birth = self:track(f.status)
            local ramp = math.min(1, (self.time - birth) / FieldFx.RAMP)
            -- A zone-bound status (`source` set) never ages -- it ends when the ground under it does
            -- -- so it must not be read as perpetually about to expire.
            local decay = f.status.source and 1
                or math.min(1, math.max(0, (f.status.remaining or 99) / FieldFx.FADE_TICKS))
            local group = "status:" .. tostring(f.status.id)
            entries[#entries + 1] = {
                x = f.x, y = f.y, pattern = pat, group = group, ord = ord,
                color = fx.color or def.color or style.color,
                -- Quieter than a zone by default: this is a condition on a body, and the body has to
                -- stay the thing you look at.
                alpha = style.alpha * (fx.density or 0.62),
                intensity = fx.intensity or 0.9,
                fade = ramp * decay,
            }
            mark(group, f.x, f.y)
        end
    end

    return entries, presence
end

-- ---------------------------------------------------------------------------
-- Draw
-- ---------------------------------------------------------------------------

-- One shader bind for the whole board; uPattern and the blend mode change only when the sorted run
-- moves on to the next family, so an 8x8 board costs a handful of state changes rather than one per
-- tile.
function FieldFx:paint(map, ordered, presence, quiet)
    local sh = self.shaderObj
    local size = map.size
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setShader(sh)
    sh:send("uTime", self.time)
    local curPattern, curBlend
    for _, e in ipairs(ordered) do
        local style = STYLE[e.pattern]
        if e.pattern ~= curPattern then
            curPattern = e.pattern
            sh:send("uPattern", FieldShader.PATTERNS[e.pattern])
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
        local wx, wy = map:cellToPixel(e.x, e.y)
        love.graphics.draw(self.px, wx, wy, 0, size, size)
    end
    love.graphics.setShader()
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(1, 1, 1, 1)
end

-- The ground fields: hazards and carried statuses, drawn in ui/battle_map.lua's old drawHazards slot
-- -- under the move/range overlays, the units and the HP bars, which is where scenery belongs.
function FieldFx:draw(map, overlays)
    overlays = overlays or {}
    if not self:shader() then return self:drawFallback(map, overlays) end

    local entries, presence = self:collect(overlays)
    if #entries == 0 then return end

    -- Normalise per TILE (that is where the compositing happens), then flatten and re-sort so the
    -- whole board draws one family at a time. Sorting globally cannot disturb the per-tile order:
    -- the leading key is the layer, which is shared by every tile.
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
        if a.group ~= b.group then return tostring(a.group) < tostring(b.group) end
        return (a.ord or 0) < (b.ord or 0)
    end)

    -- An armed ability owns the board while the player is steering it, so the scenery steps back.
    local quiet = (overlays.aoe and #overlays.aoe > 0) and FieldFx.QUIET or 1
    self:paint(map, ordered, presence, quiet)
end

-- A TELEGRAPH: the footprint an armed or channelling ability is about to cover, drawn OVER the
-- interaction overlays rather than under them (ui/battle_map.lua's drawOverlays calls this) and
-- deliberately outside the ground fields' alpha budget -- the thing about to happen must not be
-- dimmed by the ground it is about to happen on.
--
-- `opts` = { pattern, color, alpha, intensity, group }. Taking the pattern from the ARMED ITEM's
-- tags is the whole point: a Fireball previews the flame it is about to leave, in the same picture
-- the resulting hazard will draw, so the promise and the result are visibly the same thing.
function FieldFx:drawTelegraph(map, cells, opts)
    if not cells or #cells == 0 then return end
    opts = opts or {}
    local pat = opts.pattern
    if not (pat and STYLE[pat]) then return end
    if not self:shader() then return end

    local style = STYLE[pat]
    local group = opts.group or ("telegraph:" .. pat)
    local presence = { [group] = {} }
    local ordered = {}
    for _, c in ipairs(cells) do
        presence[group][c.x .. "," .. c.y] = true
        ordered[#ordered + 1] = {
            x = c.x, y = c.y, pattern = pat, group = group, ord = 0,
            color = opts.color or style.color,
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

-- What the board drew before the shader existed, kept for the machine whose driver refuses the
-- GLSL: a translucent tile wash plus a border, tinted by disposition (hostile orange / friendly
-- green / neutral blue). Loses the identity, the stacking and the animation, and still says
-- correctly where the ground is dangerous.
local FALLBACK = {
    hostile  = { 0.95, 0.45, 0.25 },
    friendly = { 0.40, 0.85, 0.50 },
}
local FALLBACK_NEUTRAL = { 0.55, 0.72, 0.95 }

function FieldFx:drawFallback(map, overlays)
    local s = map.size
    for _, h in ipairs(overlays.hazards or {}) do
        if h.alive then
            local wx, wy = map:cellToPixel(h.x, h.y)
            local c = FALLBACK[h.def and h.def.disposition] or FALLBACK_NEUTRAL
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
