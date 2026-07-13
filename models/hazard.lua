-- Hazards: persistent area effects painted onto the combat grid -- a patch of fire, a rain cloud, a
-- sanctuary. Kin to traps (models/trap.lua), but with the opposite temperament: a hazard CANNOT be
-- destroyed, can be freely moved into / stood on by EITHER side, is ALWAYS visible, occupies many
-- tiles (one runtime object per covered cell, like a trap is per-cell), and PERSISTS for a duration
-- that counts down on the shared initiative clock. When a unit ENTERS a hazard tile the effect fires;
-- the effect is delivered as a status (Status.apply), which then lingers/ticks on its own -- and,
-- being one-instance-per-id, refreshes rather than stacks on re-entry. Whether the effect respects
-- sides is the def's own business: fire burns friend and foe alike, while a sanctuary blesses only
-- its caster's side (see Hazard.allied / ctx.isAlly). Pure logic (no love.graphics beyond the
-- tolerant Sprite loader), so it loads under the headless tests.
--
-- Blueprints live in data/hazards/<id>.lua and expose:
--   * duration      -- ticks the hazard tile persists (default 1)
--   * disposition   -- "hostile" | "friendly" | "neutral": drives the enemy AI's avoid/seek (default
--                      neutral). A "friendly" hazard only draws the side that owns it.
--   * tags          -- descriptive tags (e.g. { "fire" }); a cast whose tags meet a hazard's
--                      dousedByTags removes it
--   * dousedByTags  -- tags that dispel this hazard when a matching cast covers its tile (e.g. water -> fire)
--   * spread        -- { intoTag = "burnable" }: each tick, seed fresh hazards on adjacent tiles
--                      carrying that terrain tag (fire creeping through a forest)
--   * onEnter(ctx)  -- fired for a unit entering (or already standing on, at placement) the tile;
--                      ctx.unit is that unit
--   * onExpire(ctx) -- fired when the hazard's duration runs out
--
-- `ctx` carries { combat, hazard, unit } plus bound, headless-safe helpers (applyStatus / heal /
-- damage / unitsNear / isAlly). Combat/Status are pulled through a LAZY require so this module never
-- sits in a load-time require cycle (combat.lua requires this module).

local Registry = require("models.registry")
local Sprite = require("models.sprite")

local Hazard = {}

Hazard.defs = Registry.load("data/hazards", "data.hazards")

-- AI bias weight applied per hazard on a tile (see Hazard.tileBias): a strong tie-breaker the enemy
-- planner folds into its destination scoring so it steps around fire and toward a sanctuary.
Hazard.HOSTILE_BIAS = 6
Hazard.FRIENDLY_BIAS = 6

-- Orthogonal neighbor offsets (matches the movement DIRS in models/combat.lua); used by spread.
local DIRS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }

local function hasTag(tags, want)
    for _, t in ipairs(tags or {}) do
        if t == want then return true end
    end
    return false
end

-- Is `side` on the hazard's team? A hazard summoned by a cast carries its caster's side, so a
-- Sanctuary the priest consecrates blesses the party and not the bandits standing in it. An
-- arena-authored hazard may have no owner (hallowed ground that was simply always there) -- with no
-- side to take, it counts everyone as an ally.
function Hazard.allied(hazard, side)
    return not hazard.side or not side or hazard.side == side
end

-- Build the effect context handed to a hazard def's hooks. Combat/Status are required lazily (at
-- call time, not load time) so combat.lua -> hazard.lua stays a one-way dependency.
local function ctxFor(combat, hazard, unit)
    local Combat = require("models.combat")
    local Status = require("models.status")
    return {
        combat = combat,
        hazard = hazard,
        unit = unit,
        applyStatus = function(tgt, id, opts)
            if not tgt then return nil end
            return Status.apply(combat, tgt, id, opts)
        end,
        heal = function(tgt, amount)
            if not tgt then return 0 end
            return Combat.applyHeal(combat, tgt, amount)
        end,
        damage = function(tgt, amount, tags)
            if not tgt then return 0 end
            return Combat.dealFlatDamage(combat, tgt, amount, tags, hazard.name or hazard.id)
        end,
        unitsNear = function(x, y, radius) return Combat.unitsNear(combat, x, y, radius) end,
        isAlly = function(tgt) return tgt ~= nil and Hazard.allied(hazard, tgt.side) end,
    }
end

-- Every live hazard on a tile (a list; distinct hazards may share a cell, e.g. rain over sanctuary).
function Hazard.allAt(combat, x, y)
    local out = {}
    for _, h in ipairs(combat.hazards or {}) do
        if h.alive and h.x == x and h.y == y then out[#out + 1] = h end
    end
    return out
end

-- The first live hazard of blueprint `id` on a tile, or nil. Used to dedupe placement (refresh
-- rather than stack a second identical hazard).
function Hazard.at(combat, x, y, id)
    for _, h in ipairs(combat.hazards or {}) do
        if h.alive and h.x == x and h.y == y and (not id or h.id == id) then return h end
    end
    return nil
end

-- Run every live hazard on (x, y) against `unit`: fire each def's onEnter. Called from
-- Combat.moveUnit for each newly entered path tile, and from Hazard.place when a hazard lands on an
-- occupied tile. Side-agnostic: fire burns friend and foe alike.
function Hazard.onEnter(combat, unit, x, y)
    if not (unit and unit.alive) then return end
    for _, h in ipairs(Hazard.allAt(combat, x, y)) do
        if h.def.onEnter then h.def.onEnter(ctxFor(combat, h, unit)) end
    end
end

-- Place a hazard of blueprint `id` at (x, y). Appends a runtime hazard to combat.hazards and returns
-- it -- or nil if the tile can't hold one. A hazard can't sit on impassable terrain (nothing stands
-- on a wall), but -- unlike a trap -- it MAY be placed on a tile a unit occupies (hazards are meant
-- to be stood in). Placing where an identical hazard already lives just refreshes its duration
-- instead of stacking a second. If a unit stands on the tile at placement it is treated as an entry,
-- so a hazard summoned onto a foe/ally takes effect at once.
function Hazard.place(combat, x, y, id, opts)
    opts = opts or {}
    local def = Hazard.defs[id]
    assert(def, "unknown hazard id: " .. tostring(id))

    local tiles = combat.arena and combat.arena.tiles
    local cell = tiles and tiles[y] and tiles[y][x]
    -- Off the map (no cell) or on impassable terrain: nothing to stand on, so no hazard takes. The
    -- off-grid guard lets an effect paint a rough footprint (a splash around a shoved foe) without
    -- clamping every cell itself -- out-of-bounds tiles are simply skipped.
    if not (cell and cell.walkable) then return nil end

    combat.hazards = combat.hazards or {}

    -- Dedupe: an identical hazard already here just refreshes its remaining duration.
    local existing = Hazard.at(combat, x, y, id)
    if existing then
        existing.remaining = math.max(existing.remaining, opts.duration or def.duration or 1)
        return existing
    end

    local tags = {}
    for _, t in ipairs(def.tags or {}) do tags[#tags + 1] = t end

    local hazard = {
        id = id,
        name = def.name,
        sprite = Sprite.load(def.sprite),
        x = x, y = y,
        side = opts.side,
        remaining = opts.duration or def.duration or 1,
        alive = true,
        def = def,
        tags = tags,
    }
    combat.hazards[#combat.hazards + 1] = hazard

    -- A hazard dropped onto an occupied tile affects the occupant immediately (an entry).
    local Combat = require("models.combat")
    local occupant = Combat.unitAt(combat, x, y)
    if occupant then
        if def.onEnter then def.onEnter(ctxFor(combat, hazard, occupant)) end
    end
    return hazard
end

-- Seed fresh hazards on tiles adjacent to a spreading hazard: fire creeping into burnable terrain.
-- For each live hazard whose def declares `spread = { intoTag = "..." }`, any orthogonally-adjacent,
-- walkable tile carrying that terrain tag (e.g. forest's `burnable`) and not already holding this
-- hazard gains a fresh copy. Bounded by the terrain -- once every reachable burnable tile is alight,
-- there is nothing left to seed. Runs once per Hazard.tick.
function Hazard.spread(combat)
    local tiles = combat.arena and combat.arena.tiles
    if not tiles then return end
    -- Snapshot the current hazards so newly seeded ones don't spread again in the same pass.
    local sources = {}
    for _, h in ipairs(combat.hazards or {}) do
        if h.alive and h.def.spread and h.def.spread.intoTag then sources[#sources + 1] = h end
    end
    for _, h in ipairs(sources) do
        local tag = h.def.spread.intoTag
        for _, d in ipairs(DIRS) do
            local nx, ny = h.x + d[1], h.y + d[2]
            local cell = tiles[ny] and tiles[ny][nx]
            if cell and cell.walkable and cell[tag] and not Hazard.at(combat, nx, ny, h.id) then
                Hazard.place(combat, nx, ny, h.id)
            end
        end
    end
end

-- Count every hazard's duration down by `elapsed` ticks; expire (and fire onExpire for) any that
-- reach 0, then let survivors spread. Called from Combat.rebase with the rebase amount (the ticks
-- that just elapsed), alongside Status.tick.
function Hazard.tick(combat, elapsed)
    if not elapsed or elapsed <= 0 then return end
    local list = combat.hazards
    if not list then return end
    for i = #list, 1, -1 do
        local h = list[i]
        h.remaining = h.remaining - elapsed
        if h.remaining <= 0 then
            h.alive = false
            table.remove(list, i)
            if h.def.onExpire then h.def.onExpire(ctxFor(combat, h, nil)) end
        end
    end
    Hazard.spread(combat)
end

-- Dispel hazards over `cells` (a list of { x, y }) whose def.dousedByTags intersects `tags` -- e.g. a
-- water-tagged cast steaming out fire in its footprint. Returns the number doused.
function Hazard.douse(combat, cells, tags)
    local n = 0
    local list = combat.hazards
    if not list or not tags then return 0 end
    local cellSet = {}
    for _, c in ipairs(cells or {}) do cellSet[c.x .. "," .. c.y] = true end
    for i = #list, 1, -1 do
        local h = list[i]
        local dousedBy = h.def.dousedByTags
        if h.alive and dousedBy and cellSet[h.x .. "," .. h.y] then
            local matched = false
            for _, t in ipairs(dousedBy) do
                if hasTag(tags, t) then matched = true break end
            end
            if matched then
                h.alive = false
                table.remove(list, i)
                n = n + 1
            end
        end
    end
    return n
end

-- Signed "how much does a unit of `side` want to stand here" score for tile (x, y): negative for
-- hostile hazards (fire burns whoever walks in), positive for friendly ones (a sanctuary), zero for
-- neutral (rain). A friendly hazard only pulls the side that owns it -- the enemy gains nothing from
-- the party's sanctuary, so it must not detour onto one. Omitting `side` scores the tile for a unit
-- that every hazard counts as an ally. Pure, so the enemy planner can fold it into destination
-- scoring and tests can assert it directly.
function Hazard.tileBias(combat, x, y, side)
    local score = 0
    for _, h in ipairs(Hazard.allAt(combat, x, y)) do
        local disp = h.def.disposition
        if disp == "hostile" then
            score = score - Hazard.HOSTILE_BIAS
        elseif disp == "friendly" and Hazard.allied(h, side) then
            score = score + Hazard.FRIENDLY_BIAS
        end
    end
    return score
end

return Hazard
