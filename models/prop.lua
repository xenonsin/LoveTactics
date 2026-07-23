-- Props: the furniture of a battlefield -- a powder keg left by the armory wall, a crate of supplies,
-- a cairn of bones. Where a WALL is conjured onto the field by a caster and a TRAP is planted by a
-- side, a prop is simply THERE: scattered by the map generator off the arena's biome
-- (Arena.generateLayout), owned by nobody and hostile to nobody. It is the fourth object layer, and it
-- earns its own module rather than folding into models/wall.lua by the three things a wall never does:
--
--   1. It belongs to NO SIDE. A barrel is not the enemy's barrel -- whoever sets it off owns the blast,
--      and it will just as happily take the party's line apart as the demons'.
--   2. It REACTS TO BEING STRUCK (onDamaged / onDestroy), not to being stepped on. Its whole verb is
--      "hit it", which is the opposite temperament to a trap's "wait for someone to walk over me".
--   3. It can be PICKED UP AND THROWN (Combat.hurlObject, reached through Heave). That is the reason a
--      prop is a runtime object carrying a position rather than another entry in Arena.TILE_PROPS: a
--      terrain type cannot be moved, and moving one is half the point.
--
-- Otherwise it stands like a wall: it blocks its tile, it may screen sight, it has HP, and striking it
-- down runs its onDestroy. An explosive barrel is that hook and nothing more
-- (data/props/prop_explosive_barrel.lua) -- which is also why a barrel HEAVED into a shield wall bursts
-- on impact for free, with no special case anywhere: the collision damages it, and damage is the only
-- trigger it has.
--
-- Blueprints live in data/props/<id>.lua and expose:
--   * health        -- HP; how much damage breaks it (default 1 -- most props pop on the first solid blow)
--   * blocksMove    -- does it bar movement? (default true; a prop is a thing standing on the tile)
--   * sightCost     -- how much it obstructs a line of sight crossing its tile (default 0: waist-high,
--                      you shoot over it). Folded into Combat.hasLineOfSight beside walls and terrain.
--   * magnitude     -- the def's own effect power (a blast), overridden per-object by opts.amount so a
--                      placing ability can scale it by its upgrade level -- exactly like trap.amount
--   * color         -- { r, g, b } block colour the renderer falls back to while the art is missing
--   * tags          -- descriptive tags (routed through damage mitigation like item tags). `explosive`
--                      is what a chain reaction looks for; `flammable` marks what fire should catch.
--   * biomes        -- { forest = 2, castle = 3 }: which arena biomes scatter this prop, and how
--                      heavily. A prop with NO biomes table scatters everywhere at weight 1; a prop WITH
--                      one appears only where it is listed. That table IS "which props a biome has" --
--                      adding a prop to a biome is a line in a data file, never a branch in the generator.
--   * onDamaged(ctx) -- fired for every blow that lands, before the break check; ctx.amount is what it took
--   * onDestroy(ctx) -- fired when it is broken (or blown apart by another prop)
--
-- `ctx` carries { combat, prop, source } plus bound, headless-safe helpers (damage / damageProp /
-- applyStatus / unitsNear / propsNear). Combat/Status are pulled through a LAZY require so this module
-- never sits in a load-time require cycle (combat.lua requires this module).

local Registry = require("models.registry")
local Sprite = require("models.sprite")

local Prop = {}

Prop.defs = Registry.load("data/props", "data.props")

-- How many props a generated board scatters, before the biome's pool is consulted. A board with an
-- empty pool scatters none however this reads. Kept here rather than in the biome files because it is
-- a statement about how cluttered a TACTICS board should be, not about what a forest looks like --
-- WHICH props a biome fields is the per-prop `biomes` table's business.
Prop.SCATTER_MIN = 0
Prop.SCATTER_MAX = 3

local function hasTag(tags, want)
    for _, t in ipairs(tags or {}) do
        if t == want then return true end
    end
    return false
end

-- Build the effect context handed to a prop def's hooks. Combat/Status are required lazily (at call
-- time, not load time) so combat.lua -> prop.lua stays a one-way dependency.
local function ctxFor(combat, prop, source, amount)
    local Combat = require("models.combat")
    local Status = require("models.status")
    return {
        combat = combat,
        prop = prop,
        -- Whoever landed the blow, when there was one (nil for a chained blast or an arena teardown).
        -- A def is free to spare it: nothing here reads sides, because a prop has none.
        source = source,
        -- What this prop just took (onDamaged only); nil in onDestroy, where the interesting number is
        -- the prop's own magnitude rather than the blow that finished it.
        amount = amount,
        -- The prop's effect power: the item-level-scaled magnitude it was placed with, falling back to
        -- the blueprint's own. What a blast reads.
        power = prop.amount or prop.def.magnitude or 0,
        damage = function(tgt, dmg, tags)
            if not tgt then return 0 end
            return Combat.dealFlatDamage(combat, tgt, dmg, tags, prop.name or prop.id)
        end,
        -- Hurt ANOTHER prop -- how a chain reaction is written. Safe to aim back at the source: a prop
        -- is marked dead before its onDestroy runs, and Prop.damage refuses a dead one, so two barrels
        -- setting each other off terminates rather than recursing.
        damageProp = function(tgt, dmg)
            if not tgt then return 0 end
            return Prop.damage(combat, tgt, dmg)
        end,
        applyStatus = function(tgt, id, opts)
            if not tgt then return nil end
            return Status.apply(combat, tgt, id, opts)
        end,
        unitsNear = function(x, y, radius) return Combat.unitsNear(combat, x, y, radius) end,
        propsNear = function(x, y, radius) return Prop.near(combat, x, y, radius) end,
    }
end

-- Place a prop of blueprint `id` at (x, y). Appends a runtime prop to combat.props and returns it, or
-- nil if the tile can't hold one -- off the map, impassable terrain, a tile a unit stands on, or one
-- that already carries a prop or a wall. The authoritative backstop for every caller (the generated
-- board, an authored arena, fx.placeProp), so a scatter that rolls an occupied tile simply drops it.
function Prop.place(combat, x, y, id, opts)
    opts = opts or {}
    local def = Prop.defs[id]
    assert(def, "unknown prop id: " .. tostring(id))

    local tiles = combat.arena and combat.arena.tiles
    local cell = tiles and tiles[y] and tiles[y][x]
    if not (cell and cell.walkable) then return nil end -- off the map, or nothing to stand on
    for _, u in ipairs(combat.units or {}) do
        if u.alive and u.x == x and u.y == y then return nil end -- a unit already stands here
    end
    if Prop.at(combat, x, y) then return nil end -- one prop per tile
    local Wall = require("models.wall")
    if Wall.at(combat, x, y) then return nil end -- a wall already holds this tile

    local tags = {}
    for _, t in ipairs(def.tags or {}) do tags[#tags + 1] = t end

    local prop = {
        id = id,
        name = def.name,
        sprite = Sprite.load(def.sprite),
        x = x, y = y,
        health = opts.health or def.health or 1,
        maxHealth = opts.health or def.health or 1,
        amount = opts.amount, -- item-level-scaled effect magnitude (nil for a scattered/authored prop)
        blocksMove = def.blocksMove ~= false, -- default true
        sightCost = def.sightCost or 0,
        alive = true,
        def = def,
        tags = tags,
    }
    combat.props = combat.props or {}
    combat.props[#combat.props + 1] = prop
    return prop
end

-- The living prop on a tile, or nil.
function Prop.at(combat, x, y)
    for _, p in ipairs(combat.props or {}) do
        if p.alive and p.x == x and p.y == y then return p end
    end
    return nil
end

-- Every living prop within `radius` (Manhattan) of (x, y). What a blast sweeps to chain into its
-- neighbours; mirrors Combat.unitsNear so a def can write the two side by side.
function Prop.near(combat, x, y, radius)
    local out = {}
    for _, p in ipairs(combat.props or {}) do
        if p.alive and math.abs(p.x - x) + math.abs(p.y - y) <= (radius or 1) then
            out[#out + 1] = p
        end
    end
    return out
end

-- Does a prop bar movement onto (x, y)? Read alongside Wall.blocksAt everywhere a standing object
-- can be in the way (Combat.reachable, the path check, a shove, a blink).
function Prop.blocksAt(combat, x, y)
    local p = Prop.at(combat, x, y)
    return p ~= nil and p.blocksMove
end

-- The sight obstruction a prop on (x, y) adds to a line crossing it (0 if none).
function Prop.sightCostAt(combat, x, y)
    local p = Prop.at(combat, x, y)
    return (p and p.sightCost) or 0
end

-- Break `prop`, running its onDestroy. Marked dead BEFORE the hook fires, which is what keeps a chain
-- of blasts finite: a barrel that has already gone off cannot be set off again by the neighbour it
-- just set off (Prop.damage refuses a dead prop).
function Prop.destroy(combat, prop, source, text)
    if not prop.alive then return end
    prop.health = 0
    prop.alive = false
    local Combat = require("models.combat")
    Combat.logEvent(combat, "trap", text or string.format("%s breaks apart.", prop.name or "A prop"))
    if prop.def.onDestroy then prop.def.onDestroy(ctxFor(combat, prop, source)) end
end

-- Damage a prop, running its onDamaged for the blow and breaking it at 0 HP. Returns the amount
-- applied. Props have no defense and take no tag mitigation -- a crate is a crate -- so this is the
-- raw number, exactly as Trap.damage and Wall.damage take theirs.
function Prop.damage(combat, prop, amount, source)
    if not prop.alive then return 0 end
    prop.health = prop.health - amount
    if prop.def.onDamaged then prop.def.onDamaged(ctxFor(combat, prop, source, amount)) end
    -- onDamaged may have destroyed it itself (a barrel that goes off the instant it is touched); only
    -- break what is still standing, so onDestroy can never run twice for one blow.
    if prop.alive and prop.health <= 0 then Prop.destroy(combat, prop, source) end
    return amount
end

-- Move a prop to (x, y) -- what a throw resolves to (Combat.hurlObject). Pure bookkeeping: the caller
-- owns the collision, the impact, and whether the tile could take it at all.
function Prop.moveTo(prop, x, y)
    prop.x, prop.y = x, y
end

-- ---------------------------------------------------------------------------
-- Scatter: which props a biome fields
-- ---------------------------------------------------------------------------

-- The weighted pool of prop ids a `biome` scatters, sorted by id so a seeded roll is reproducible
-- (pairs() over Prop.defs is not ordered, and a generated board has to replay from its seed). A prop
-- with no `biomes` table is universal furniture at weight 1; one WITH a table appears only in the
-- biomes it names. Returns a list of { id, weight } plus the summed weight.
function Prop.poolFor(biome)
    local pool, total = {}, 0
    for id, def in pairs(Prop.defs) do
        local w
        if def.biomes then
            w = biome and def.biomes[biome] or nil
        else
            w = 1
        end
        if w and w > 0 then
            pool[#pool + 1] = { id = id, weight = w }
            total = total + w
        end
    end
    table.sort(pool, function(a, b) return a.id < b.id end)
    return pool, total
end

-- Draw `n` prop ids for `biome` from a seeded RNG (with replacement -- two barrels on one board is a
-- fine board). Returns an empty list when the biome fields no props at all, which is how a biome opts
-- out entirely: it simply never appears in any prop's `biomes` table.
function Prop.roll(rng, biome, n)
    local pool, total = Prop.poolFor(biome)
    local out = {}
    if total <= 0 then return out end
    for _ = 1, n or 0 do
        local pick = rng:random(1, total)
        for _, entry in ipairs(pool) do
            pick = pick - entry.weight
            if pick <= 0 then out[#out + 1] = entry.id break end
        end
    end
    return out
end

-- Dry-run a prop blueprint's onDestroy against a stand-in board to report what breaking it does -- the
-- raw (pre-mitigation) damage it throws off and any status it applies -- WITHOUT a real combat. Mirrors
-- Trap.preview and Hazard.preview: the prop's own effect is the source of truth, so the tooltip for the
-- ability that PLACES a barrel quotes the barrel's real numbers rather than a copy of them. pcall-guarded
-- so a data quirk can never crash a tooltip. Returns { damage, statuses = { { id, def } } }, or nil for
-- an unknown id. `amount` (optional) is the item-level-scaled magnitude it would be placed with.
function Prop.preview(id, amount)
    local def = Prop.defs[id]
    if not def then return nil end
    local Status = require("models.status")
    local out = { damage = 0, statuses = {} }
    local bystander = { alive = true, side = "enemy", char = { name = "target" } }
    local prop = { id = id, name = def.name, def = def, tags = def.tags or {}, amount = amount,
                   x = 0, y = 0, alive = true }
    local ctx = {
        combat = nil, prop = prop, source = nil,
        power = amount or def.magnitude or 0,
        damage = function(_, dmg) out.damage = out.damage + (dmg or 0); return dmg or 0 end,
        damageProp = function() return 0 end, -- nothing else on a one-prop board to chain into
        applyStatus = function(_, sid)
            out.statuses[#out.statuses + 1] = { id = sid, def = Status.defs[sid] }
            return nil
        end,
        unitsNear = function() return { bystander } end,
        propsNear = function() return {} end,
    }
    if def.onDestroy then pcall(def.onDestroy, ctx) end
    return out
end

-- AI bias weight applied per explosive prop in blast range of a tile (see Prop.tileBias): a strong
-- tie-breaker the enemy planner folds into its destination scoring beside Hazard.tileBias.
Prop.BLAST_BIAS = 8

-- Signed "how much does a unit want to END ITS TURN here" score for tile (x, y): negative once a live
-- explosive prop is close enough to reach it. Unlike Hazard.tileBias this reads the NEIGHBOURHOOD
-- rather than the tile itself -- a barrel's own square is blocked, so the danger a keg poses is
-- entirely a danger to the tiles around it, and a planner that only asked about the cell it stands on
-- would never see one coming.
--
-- Sideless, because the thing it is afraid of is: a keg blows up whoever is nearest it, and nobody owns
-- one. That is also what makes this worth having -- without it the enemy cheerfully lines up beside the
-- barrels and the player's best move is free, every time, on every board that scattered any.
--
-- Pure, so tests can assert it directly and the planner can run it across a whole candidate set.
function Prop.tileBias(combat, x, y)
    local score = 0
    for _, p in ipairs(combat.props or {}) do
        if p.alive and hasTag(p.tags, "explosive") then
            local r = (p.def.radius or 1)
            if math.abs(p.x - x) + math.abs(p.y - y) <= r then
                score = score - Prop.BLAST_BIAS
            end
        end
    end
    return score
end

-- Whether `prop` carries `tag` -- the one question a chain reaction asks of its neighbours.
function Prop.hasTag(prop, tag)
    return prop ~= nil and hasTag(prop.tags, tag)
end

return Prop
