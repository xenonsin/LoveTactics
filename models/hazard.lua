-- Hazards: persistent area effects painted onto the combat grid -- a patch of fire, a rain cloud, a
-- sanctuary, the square a planted banner holds. Kin to traps (models/trap.lua), but with the opposite
-- temperament: a hazard CANNOT be destroyed, can be freely moved into / stood on by EITHER side, is
-- ALWAYS visible, occupies many tiles (one runtime object per covered cell, like a trap is per-cell),
-- and PERSISTS for a duration that counts down on the shared initiative clock. When a unit ENTERS a
-- hazard tile the effect fires; the effect is delivered as a status (Status.apply) -- and, being
-- one-instance-per-id, refreshes rather than stacks on re-entry. Whether the effect respects sides is
-- the def's own business: fire burns friend and foe alike, while a sanctuary blesses only its caster's
-- side (see Hazard.allied / ctx.isAlly). Pure logic (no love.graphics beyond the tolerant Sprite
-- loader), so it loads under the headless tests.
--
-- ---------------------------------------------------------------------------
-- A hazard is the ONE zone concept. There is no separate "aura": an aura is just what you call a
-- zone-granted status that clings to its zone, and it falls out of two rules that live here.
--
-- 1. WHO ends the status -- the STATUS decides, not the zone. Every status a zone grants is stamped
--    with that zone's id as its `source` (see the ctx's applyStatus), unless the status declares
--    `lingers`. A `lingers` status (Burn, Poison, Wet) travels with the unit and runs its own duration
--    wherever it goes: you carry the flames out of the fire. Anything else is ZONE-BOUND (Regeneration,
--    Mired, Inspiration) -- it does not age at all (Status.tick skips it), it lasts exactly as long as
--    a live zone granting it sits under its bearer, and Hazard.reap ends it the instant one doesn't.
--    Stamping the source here rather than at each call site is what keeps that a property of the
--    status, so no zone def can get it wrong by forgetting an argument.
--
-- 2. WHEN it ends -- two ways to stop standing in a zone, one path. The unit walks off it
--    (Combat.enterTile -> Hazard.reap), or the ground goes out from under a unit that never moved:
--    its duration ran out, or its OWNER was cut down (Hazard.tick -> Hazard.reap). Both end a blessing
--    identically, because both are the same question asked once a beat: is a zone that grants this
--    still under you?
--
-- An `owner` is what ties a zone to a body on the field. A banner is nothing but a destructible object
-- that owns its square (data/characters/banner.lua): it takes no turns and has no effect of its own,
-- and killing it removes the ground, which removes the buff. "The banner rallies nearby allies" is an
-- emergent reading of those two rules rather than a mechanic anyone had to write.
-- ---------------------------------------------------------------------------
--
-- Blueprints live in data/hazards/<id>.lua and expose:
--   * duration      -- ticks the hazard tile persists (default 1). An owned zone quotes a huge one and
--                      really answers to its owner's life (see Hazard.dropOwnedBy).
--   * owner         -- (runtime, via Hazard.place opts) the unit holding this zone open; nil for a zone
--                      that answers only to its duration
--   * disposition   -- "hostile" | "friendly" | "neutral": drives the enemy AI's avoid/seek (default
--                      neutral). A "friendly" hazard only draws the side that owns it.
--   * tags          -- descriptive tags (e.g. { "fire" }). Two jobs: a cast whose tags meet a
--                      hazard's dousedByTags removes it, AND the hazard lends these tags to the TILE
--                      it sits on (Combat.tileHasTag) -- which is how a Rain cloud's "conductable"
--                      makes drenched ground carry a bolt, just as water terrain does.
--   * dousedByTags  -- tags that dispel this hazard when a matching cast covers its tile (e.g. water -> fire)
--   * spread        -- { intoTag = "burnable" }: each tick, seed fresh hazards on adjacent tiles
--                      carrying that tag (fire creeping through a forest). The tag is resolved
--                      against terrain, hazards and statuses alike -- see Hazard.spread.
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
        -- The item-level-scaled magnitude the placing ability handed in (or nil for an arena-authored
        -- hazard). A hazard's onEnter feeds it to the status it grants (a hotter fire, a stronger
        -- Regeneration); passing nil lets that status fall back to its own blueprint default.
        amount = hazard.amount,
        -- Grant a status FROM THIS ZONE. The zone's id is stamped on it as `source` automatically,
        -- unless the status declares `lingers` -- so which statuses cling to their zone and which
        -- travel with the unit is decided once, by the status itself, and no zone def can get it
        -- wrong by forgetting an argument. Hazard.reap reads that stamp; see the module header.
        applyStatus = function(tgt, id, opts)
            if not tgt then return nil end
            local def = Status.defs[id]
            if def and not def.lingers then
                opts = opts or {}
                opts.source = hazard.id
            end
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

-- The first live hazard of blueprint `id` on a tile, or nil -- whoever owns it. What Hazard.reap asks:
-- "is any live zone granting this still under the unit?", where a second banner's overlapping square
-- answers just as well as the first.
function Hazard.at(combat, x, y, id)
    for _, h in ipairs(combat.hazards or {}) do
        if h.alive and h.x == x and h.y == y and (not id or h.id == id) then return h end
    end
    return nil
end

-- How much this tile's hazards obstruct a line of sight drawn ACROSS it: the summed `sightCost` of
-- every live zone standing on it. 0 for the overwhelming majority, which declare none -- fire and rain
-- are things you see through perfectly well, and only a zone whose whole point is blindness (Darkness)
-- has any business here.
--
-- The third and last contributor to Combat.hasLineOfSight, beside Wall.sightCostAt and Prop.sightCostAt
-- and shaped exactly like them, which is what makes the addition cheap: sight already asked terrain,
-- walls and furniture what they cost to see past, and this only widens the question to the ground
-- itself. Everything that reads sight -- a bow's `requiresSight`, the threat highlight, overwatch, the
-- enemy AI -- picks up the new answer without knowing a hazard was involved.
--
-- SUMMED rather than maxed, so two clouds drifting over one tile blind it harder than one does. That
-- matches how terrain already stacks toward Combat.SIGHT_BLOCK (two forests block where one does not).
function Hazard.sightCostAt(combat, x, y)
    local total = 0
    for _, h in ipairs(Hazard.allAt(combat, x, y)) do
        total = total + (h.def.sightCost or 0)
    end
    return total
end

-- The live hazard of blueprint `id` on a tile belonging to exactly `owner` (nil owner matches only an
-- unowned zone), or nil. Placement's dedupe key -- deliberately narrower than Hazard.at, which cannot
-- tell "any owner" from "no owner" through one optional argument.
local function sameZoneAt(combat, x, y, id, owner)
    for _, h in ipairs(combat.hazards or {}) do
        if h.alive and h.x == x and h.y == y and h.id == id and h.owner == owner then return h end
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

    -- Dedupe: an identical hazard already here just refreshes its remaining duration. Keyed on the
    -- OWNER as well as the id, so two banners whose squares overlap each keep their own zone on the
    -- shared tile -- otherwise the second would fold into the first, and cutting down one banner would
    -- strip ground the other is still holding.
    local existing = sameZoneAt(combat, x, y, id, opts.owner)
    if existing then
        existing.remaining = math.max(existing.remaining, opts.duration or def.duration or 1)
        -- A stronger re-cast overwrites a weaker magnitude; a bare refresh (or spread) leaves it be.
        if opts.amount and opts.amount > (existing.amount or 0) then existing.amount = opts.amount end
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
        amount = opts.amount, -- item-level-scaled effect magnitude (nil for an arena-authored hazard)
        alive = true,
        def = def,
        tags = tags,
        -- The field object holding this zone open (a planted banner). While it lives the zone stands;
        -- when it dies the zone goes with it, and whatever it was granting unwinds by the ordinary
        -- rules. nil for a zone that answers to nothing but its own duration -- a fire, a rain cloud.
        owner = opts.owner,
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

-- Seed fresh hazards on tiles adjacent to a spreading hazard: fire creeping into burnable ground.
-- For each live hazard whose def declares `spread = { intoTag = "..." }`, any orthogonally-adjacent,
-- walkable tile carrying that tag and not already holding this hazard gains a fresh copy. The tag is
-- resolved through Combat.tileHasTag, which reads terrain, hazards and the occupant's statuses alike
-- -- so fire creeps into forest ("burnable" terrain) and would equally take an oil slick or a
-- pitch-soaked unit, with no change here. Bounded by the ground: once every reachable burnable tile
-- is alight, there is nothing left to seed. Runs once per Hazard.tick.
function Hazard.spread(combat)
    local tiles = combat.arena and combat.arena.tiles
    if not tiles then return end
    local Combat = require("models.combat")
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
            if cell and cell.walkable and Combat.tileHasTag(combat, nx, ny, tag)
                and not Hazard.at(combat, nx, ny, h.id) then
                -- Carry the source's scaled magnitude into the tile it spreads to, so a hot fire keeps
                -- burning just as hard as it creeps.
                Hazard.place(combat, nx, ny, h.id, { side = h.side, amount = h.amount })
            end
        end
    end
end

-- Drop every zone `owner` was holding open -- its banner is down, so its ground goes with it. Returns
-- the number removed. Called from the death path (Combat.kill) the instant the owner falls, so the
-- rally ends on that beat rather than at the next rebase; Hazard.tick sweeps as a backstop for any
-- unit that left the field by a path the death path doesn't cover.
--
-- `id` optionally narrows it to one blueprint, mirroring Hazard.at's optional id: nil means "every
-- zone this owner holds" (the death path wants all of them), while a caller that holds several kinds
-- of ground open and means to lift only one names it. Combat.layIncense is that caller -- a censer
-- lifts its own smoke each time it moves, and must not take a zone the bearer holds by other means.
--
-- Only removes the ZONES. The statuses they were granting are not touched here: they unwind by the
-- ordinary rule a beat later, when Hazard.reap finds no live zone under their bearers -- so ground
-- that vanishes and ground you walk out of end a blessing the same way, through one path.
function Hazard.dropOwnedBy(combat, owner, id)
    if not owner then return 0 end
    local list = combat.hazards
    if not list then return 0 end
    local n = 0
    for i = #list, 1, -1 do
        local h = list[i]
        if h.owner == owner and (not id or h.id == id) then
            h.alive = false
            table.remove(list, i)
            if h.def.onExpire then h.def.onExpire(ctxFor(combat, h, nil)) end
            n = n + 1
        end
    end
    return n
end

-- Carry every zone `owner` holds open along with it: shift each of its hazards by (dx, dy), the same
-- delta the owner just travelled. The ground a body holds open is held open WHERE THAT BODY IS -- so a
-- banner heaved across the field takes its rally square with it, and does not leave a live 3x3 blessing
-- standing over the ground it used to occupy.
--
-- A banner never walks, so this only ever fires when something MOVES one (Heave, a shove, a charge) --
-- which is exactly the case that would otherwise strand a zone. Translating rather than re-laying keeps
-- each cell's remaining duration, magnitude and side intact, and keeps the zone's SHAPE: a 3x3 stays a
-- 3x3 rather than being rebuilt by whichever ability happened to author it. A cell that lands off the
-- map or on unwalkable ground is dropped instead (a zone clipped by the wall it was thrown against),
-- mirroring Hazard.place's refusal of the same tiles.
--
-- Distinct from Combat.layIncense, which DROPS and re-lays a censer's cloud each time its bearer moves.
-- A censer generates its ground continuously from a def, so re-laying is the cheaper truth; a banner's
-- square was authored once by the ability that planted it, and there is nothing left to re-lay it from.
-- Combat.enterTile calls this BEFORE layIncense so a censer-bearer's cloud is corrected by the re-lay
-- rather than shifted twice.
--
-- Occupants are then re-entered: a zone that arrives over a unit affects it at once, exactly as
-- Hazard.place treats a hazard dropped onto an occupied tile. Reaping the units the ground left behind
-- is NOT done here -- Hazard.reap runs for every living unit on the next tick, and a blessing that
-- outlasts the banner by a beat is the same lag a banner cut down between ticks already has.
-- Returns the number of zone cells carried.
function Hazard.carry(combat, owner, dx, dy)
    if not owner then return 0 end
    if dx == 0 and dy == 0 then return 0 end
    local list = combat.hazards
    if not list then return 0 end
    local tiles = combat.arena and combat.arena.tiles
    local moved = {}
    for i = #list, 1, -1 do
        local h = list[i]
        if h.alive and h.owner == owner then
            local nx, ny = h.x + dx, h.y + dy
            local cell = tiles and tiles[ny] and tiles[ny][nx]
            if cell and cell.walkable then
                h.x, h.y = nx, ny
                moved[#moved + 1] = h
            else
                h.alive = false
                table.remove(list, i)
                if h.def.onExpire then h.def.onExpire(ctxFor(combat, h, nil)) end
            end
        end
    end
    local Combat = require("models.combat")
    for _, h in ipairs(moved) do
        local occupant = Combat.unitAt(combat, h.x, h.y)
        if occupant and occupant.alive and h.def.onEnter then
            h.def.onEnter(ctxFor(combat, h, occupant))
        end
    end
    return #moved
end

-- Drop any ZONE-BOUND status `unit` is no longer standing in. Such a status carries `source` = the id
-- of the zone that granted it (stamped automatically -- see the ctx's applyStatus); it lives exactly
-- as long as a live zone of that id sits under the unit, and Status.tick never ages it. This is the
-- one place it can end.
--
-- Called from Combat.enterTile -- the chokepoint every position change routes through (a walk step, a
-- knockback, a summon appearing) -- so leaving a Sanctuary ends its blessing on the very beat the unit
-- steps off. And called from Hazard.tick for every living unit, which is the half a move-driven check
-- alone cannot cover: the ground can vanish from under a unit that never moves at all -- its duration
-- spent, or the banner holding it open cut down. A status with no `source` (a spell, a potion) is
-- never touched.
-- Removal goes through Status.remove rather than lifting the entry out of the list here, so a
-- zone-bound status unwinds whatever it was holding (Status.remove fires its onExpire with a proper
-- status ctx). Leaving a zone therefore tears a status down exactly as a Cure or a natural expiry
-- would -- there is no removal path that can strand a unit in a state its status was meant to revert.
function Hazard.reap(combat, unit)
    local list = unit.statuses
    if not list then return end
    local Status = require("models.status")
    local Combat = require("models.combat")
    -- Snapshot the ids to drop before touching the list: Status.remove mutates it, and an onExpire is
    -- free to mutate it further.
    local dropped = {}
    for _, s in ipairs(list) do
        if s.source and not Hazard.at(combat, unit.x, unit.y, s.source) then
            dropped[#dropped + 1] = s
        end
    end
    for _, s in ipairs(dropped) do
        Status.remove(combat, unit, s.id)
        if not s.def.hideLog then
            Combat.logEvent(combat, "status",
                string.format("%s's %s fades outside the %s.",
                    (unit.char and unit.char.name) or "Unit", s.name or s.id,
                    Hazard.defs[s.source] and Hazard.defs[s.source].name or "zone"), unit)
        end
    end
end

-- One full turn of the zone cycle, called from Combat.rebase with the ticks that just elapsed,
-- alongside Status.tick. In order:
--   1. age every zone and expire the ones that run out,
--   2. drop any zone whose owner has died,
--   3. reap the zone-bound statuses left with no zone under them (steps 1 and 2 just removed the
--      ground out from under units that never moved -- nothing else would notice),
--   4. let the survivors spread.
-- Reaping after the removals, and not before, is what makes "the hazard is removed from the tile" and
-- "the unit walked off the tile" the same event as far as a blessing is concerned.
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
    for i = #list, 1, -1 do
        local h = list[i]
        if h.owner and not h.owner.alive then
            h.alive = false
            table.remove(list, i)
            if h.def.onExpire then h.def.onExpire(ctxFor(combat, h, nil)) end
        end
    end
    for _, unit in ipairs(combat.units or {}) do
        if unit.alive then Hazard.reap(combat, unit) end
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

-- Dry-run a hazard blueprint's onEnter against a stand-in occupant to report what standing in it does
-- -- the status it grants (with the magnitude it would carry at `amount`) and any direct heal/damage --
-- WITHOUT a real combat. Mirrors Trap.preview: the hazard's own effect is the source of truth, so the
-- inventory tooltip can describe a Sanctuary or a Fire without duplicating its numbers. The stand-in
-- counts as an ally so a side-gated hazard (Sanctuary) still fires. pcall-guarded against a data quirk.
-- Returns { heal, damage, statuses = { { id, def, magnitude } } }, or nil for an unknown id.
function Hazard.preview(id, amount)
    local def = Hazard.defs[id]
    if not def then return nil end
    local Status = require("models.status")
    local out = { heal = 0, damage = 0, statuses = {} }
    local unit = { alive = true, side = "party", char = { name = "ally" } }
    local ctx = {
        combat = nil,
        hazard = { id = id, name = def.name, def = def, tags = def.tags or {}, amount = amount },
        unit = unit,
        amount = amount,
        applyStatus = function(_, sid, opts)
            local sdef = Status.defs[sid]
            out.statuses[#out.statuses + 1] = { id = sid, def = sdef,
                magnitude = (opts and opts.magnitude) or (sdef and sdef.magnitude) }
            return nil
        end,
        heal = function(_, a) out.heal = out.heal + (a or 0); return a or 0 end,
        damage = function(_, a) out.damage = out.damage + (a or 0); return a or 0 end,
        unitsNear = function() return { unit } end,
        isAlly = function() return true end,
    }
    if def.onEnter then pcall(def.onEnter, ctx) end
    return out
end

return Hazard
