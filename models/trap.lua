-- Traps: tile objects placed in a combat arena, owned by a side. A trap is hidden from the
-- owner's opponents unless one of their units carries a "detect traps" item within range; a
-- unit that paths over an opposing trap triggers it (damage or a status effect, single-target
-- or AoE), and a revealed trap has HP and can be attacked down. Pure logic (no love.graphics
-- beyond the tolerant Sprite loader), so it loads under the headless tests.
--
-- Blueprints live in data/traps/<id>.lua and expose:
--   * health              -- HP; how much damage destroys the trap (default 1)
--   * onTrigger(ctx)      -- fired when an opposing unit enters the tile; ctx.victim is that unit
--   * onDestroy(ctx)      -- fired when the trap is damaged to 0 HP
--   * consumedOnTrigger   -- default true: the trap is spent after one trigger; false = persistent
--   * tags                -- descriptive tags (routed through damage mitigation like item tags)
--
-- `ctx` carries { combat, trap, victim } plus bound, headless-safe helpers (damage /
-- applyStatus / unitsNear). Combat/Status are pulled through a LAZY require so this module
-- never sits in a load-time require cycle (combat.lua requires this module).

local Registry = require("models.registry")
local Sprite = require("models.sprite")

local Trap = {}

Trap.defs = Registry.load("data/traps", "data.traps")

Trap.DETECT_TAG = "detect traps"
Trap.DEFAULT_DETECT_RADIUS = 2

local function manhattan(ax, ay, bx, by)
    return math.abs(ax - bx) + math.abs(ay - by)
end

local function hasTag(tags, want)
    for _, t in ipairs(tags or {}) do
        if t == want then return true end
    end
    return false
end

-- Build the effect context handed to a trap def's hooks. Combat/Status are required lazily
-- (at call time, not load time) so combat.lua -> trap.lua stays a one-way dependency.
local function ctxFor(combat, trap, victim)
    local Combat = require("models.combat")
    local Status = require("models.status")
    return {
        combat = combat,
        trap = trap,
        victim = victim,
        damage = function(tgt, amount, tags)
            if not tgt then return 0 end
            return Combat.dealFlatDamage(combat, tgt, amount, tags, trap.name or trap.id)
        end,
        applyStatus = function(tgt, id, opts)
            if not tgt then return nil end
            return Status.apply(combat, tgt, id, opts)
        end,
        unitsNear = function(x, y, radius) return Combat.unitsNear(combat, x, y, radius) end,
    }
end

-- Place a trap of blueprint `id` at (x, y), owned by `side` ("party"/"enemy"). Appends a
-- runtime trap to combat.traps and returns it -- or nil if the tile can't hold one. A trap can't
-- sit on impassable terrain (a solid obstacle) -- nothing paths over a wall to trigger it -- nor
-- on a tile a unit already occupies, so this refuses either. The authoritative backstop for every
-- caller (authored arena data, fx.placeTrap); Combat.useItem also blocks the player's tile-target
-- cast earlier so no turn is wasted on it.
function Trap.place(combat, x, y, id, side, opts)
    opts = opts or {}
    local def = Trap.defs[id]
    assert(def, "unknown trap id: " .. tostring(id))

    local tiles = combat.arena and combat.arena.tiles
    local cell = tiles and tiles[y] and tiles[y][x]
    if cell and not cell.walkable then return nil end
    for _, u in ipairs(combat.units or {}) do
        if u.alive and u.x == x and u.y == y then return nil end -- a unit already stands here
    end

    local tags = {}
    for _, t in ipairs(def.tags or {}) do tags[#tags + 1] = t end

    local trap = {
        id = id,
        name = def.name,
        sprite = Sprite.load(def.sprite),
        x = x, y = y,
        side = side or "enemy",
        health = def.health or 1,
        maxHealth = def.health or 1,
        amount = opts.amount, -- item-level-scaled trigger magnitude (nil for an arena-authored trap)
        alive = true,
        def = def,
        tags = tags,
    }
    combat.traps = combat.traps or {}
    combat.traps[#combat.traps + 1] = trap
    return trap
end

-- The living trap on a tile, or nil.
function Trap.at(combat, x, y)
    for _, t in ipairs(combat.traps or {}) do
        if t.alive and t.x == x and t.y == y then return t end
    end
    return nil
end

-- The best "detect traps" radius among a character's items, or nil if it carries no detector.
-- Uses `pairs`, not `ipairs`: the 3x3 grid is a sparse array (a removed item leaves a gap), and
-- ipairs would stop at the first empty cell and miss a detector sitting past it. Order doesn't matter
-- here -- we take the max radius across every carried detector.
local function detectorRadius(char)
    local best
    for _, item in pairs(char.inventory or {}) do
        if hasTag(item.tags, Trap.DETECT_TAG) then
            local r = item.detectRadius or Trap.DEFAULT_DETECT_RADIUS
            if not best or r > best then best = r end
        end
    end
    return best
end

-- Is `trap` visible to `side`? Always to its owner; to opponents only when some living unit of
-- `side` carries a "detect traps" item within that item's detectRadius (Manhattan) of the trap.
function Trap.visibleTo(combat, trap, side)
    if not trap.alive then return false end
    if side == trap.side then return true end
    for _, u in ipairs(combat.units) do
        if u.alive and u.side == side then
            local r = detectorRadius(u.char)
            if r and manhattan(u.x, u.y, trap.x, trap.y) <= r then return true end
        end
    end
    return false
end

-- Living traps visible to `side` (for the renderer / targeting).
function Trap.revealedTo(combat, side)
    local out = {}
    for _, t in ipairs(combat.traps or {}) do
        if Trap.visibleTo(combat, t, side) then out[#out + 1] = t end
    end
    return out
end

-- Trigger `trap` against `victim` (the unit that entered its tile). No-op unless the victim is
-- alive and on the opposing side. Runs the def's onTrigger and spends the trap unless the def
-- opts out with consumedOnTrigger = false. Returns true if it fired.
function Trap.trigger(combat, trap, victim)
    if not (trap.alive and victim and victim.alive) then return false end
    if victim.side == trap.side then return false end
    local Combat = require("models.combat")
    Combat.logEvent(combat, "trap",
        string.format("%s triggers %s!", (victim.char and victim.char.name) or "Unit", trap.name or "a trap"))
    if trap.def.onTrigger then trap.def.onTrigger(ctxFor(combat, trap, victim)) end
    if trap.def.consumedOnTrigger ~= false then trap.alive = false end
    return true
end

-- Dry-run a trap blueprint's onTrigger against a stand-in victim to report what crossing its tile
-- would do -- the raw (pre-mitigation) damage it deals and any status it applies -- WITHOUT a real
-- combat. Mirrors Combat.abilityOutput's approach for ability items: the trap's own effect is the
-- source of truth, so a data-only trap (spike = damage, snare = a status) is described without its
-- numbers being duplicated anywhere. pcall-guarded so a data quirk can never crash a tooltip.
-- Returns { damage, statuses = { { id, def } } }, or nil for an unknown id. `amount` (optional) is the
-- item-level-scaled magnitude the trap was placed with, so the preview quotes the damage it will really
-- deal at that upgrade level rather than the blueprint's base.
function Trap.preview(id, amount)
    local def = Trap.defs[id]
    if not def then return nil end
    local Status = require("models.status")
    local out = { damage = 0, statuses = {} }
    local victim = { alive = true, side = "enemy", char = { name = "target" } }
    local trap = { id = id, name = def.name, def = def, tags = def.tags or {}, amount = amount }
    local ctx = {
        combat = nil, trap = trap, victim = victim,
        damage = function(_, amount) out.damage = out.damage + (amount or 0); return amount or 0 end,
        applyStatus = function(_, sid)
            out.statuses[#out.statuses + 1] = { id = sid, def = Status.defs[sid] }
            return nil
        end,
        unitsNear = function() return { victim } end,
    }
    if def.onTrigger then pcall(def.onTrigger, ctx) end
    return out
end

-- Damage a (revealed) trap. Destroys it at 0 HP, running the def's onDestroy. Returns the
-- amount applied.
function Trap.damage(combat, trap, amount)
    if not trap.alive then return 0 end
    trap.health = trap.health - amount
    if trap.health <= 0 then
        trap.health = 0
        trap.alive = false
        local Combat = require("models.combat")
        Combat.logEvent(combat, "trap", string.format("%s is destroyed.", trap.name or "A trap"))
        if trap.def.onDestroy then trap.def.onDestroy(ctxFor(combat, trap, nil)) end
    end
    return amount
end

return Trap
