-- Walls: conjured blockers placed on arena tiles. Where a trap is a hidden thing that fires when
-- stepped on, a wall is a plain obstacle that stands in the way -- it stops movement, screens line
-- of sight, and can be struck down like a revealed trap. Summon Wall raises a 3x1 line of them
-- (data/items/ability/ability_summon_wall.lua); Dispel Illusions clears any tagged `illusion`
-- (data/items/ability/ability_dispel_illusions.lua). Pure logic (no love.graphics beyond the
-- tolerant Sprite loader), so it loads under the headless tests, mirroring models/trap.lua.
--
-- Blueprints live in data/walls/<id>.lua and expose:
--   * health      -- HP; how much damage tears the wall down (default 1)
--   * blocksMove  -- does it bar movement? (default true)
--   * sightCost   -- how much it obstructs a line of sight passing through its tile (default 2 =
--                    a full block on its own; folded into Combat.hasLineOfSight)
--   * duration    -- ticks it stands before it fades (nil = until struck down or dispelled)
--   * tags        -- descriptive tags; `illusion` marks it as Dispel's quarry
--   * onDestroy(ctx) -- optional, fired when it is torn down or dispelled
--
-- Combat/Status are pulled through a LAZY require so this module never sits in a load-time cycle.

local Registry = require("models.registry")
local Sprite = require("models.sprite")

local Wall = {}

Wall.defs = Registry.load("data/walls", "data.walls")

-- Place a wall of blueprint `id` at (x, y). Appends a runtime wall to combat.walls and returns it,
-- or nil if the tile can't hold one -- impassable terrain, a tile a unit stands on, or one that
-- already carries a wall. `opts.side` tints it; `opts.duration` overrides the blueprint's.
function Wall.place(combat, x, y, id, opts)
    opts = opts or {}
    local def = Wall.defs[id]
    assert(def, "unknown wall id: " .. tostring(id))

    local tiles = combat.arena and combat.arena.tiles
    local cell = tiles and tiles[y] and tiles[y][x]
    if cell and not cell.walkable then return nil end
    if not cell then return nil end -- off the map
    for _, u in ipairs(combat.units or {}) do
        if u.alive and u.x == x and u.y == y then return nil end -- a unit stands here
    end
    if Wall.at(combat, x, y) then return nil end -- one wall per tile

    local tags = {}
    for _, t in ipairs(def.tags or {}) do tags[#tags + 1] = t end

    local wall = {
        id = id,
        name = def.name,
        sprite = Sprite.load(def.sprite),
        x = x, y = y,
        side = opts.side or "party",
        health = def.health or 1,
        maxHealth = def.health or 1,
        blocksMove = def.blocksMove ~= false, -- default true
        sightCost = def.sightCost or 2,
        remaining = opts.duration or def.duration, -- nil = stands until struck down / dispelled
        alive = true,
        def = def,
        tags = tags,
    }
    combat.walls = combat.walls or {}
    combat.walls[#combat.walls + 1] = wall
    return wall
end

-- The living wall on a tile, or nil.
function Wall.at(combat, x, y)
    for _, w in ipairs(combat.walls or {}) do
        if w.alive and w.x == x and w.y == y then return w end
    end
    return nil
end

-- Does a wall bar movement onto (x, y)? Read by Combat.reachable and the forced-movement gate.
function Wall.blocksAt(combat, x, y)
    local w = Wall.at(combat, x, y)
    return w ~= nil and w.blocksMove
end

-- The sight obstruction a wall on (x, y) adds to a line crossing it (0 if none). Folded into
-- Combat.hasLineOfSight alongside the tile's own sightCost.
function Wall.sightCostAt(combat, x, y)
    local w = Wall.at(combat, x, y)
    return (w and w.sightCost) or 0
end

local function destroy(combat, wall, text)
    wall.health = 0
    wall.alive = false
    local Combat = require("models.combat")
    Combat.logEvent(combat, "trap", text or string.format("%s is destroyed.", wall.name or "A wall"))
    if wall.def.onDestroy then
        wall.def.onDestroy({ combat = combat, wall = wall })
    end
end

-- Damage a wall, tearing it down at 0 HP (running the def's onDestroy). Returns the amount applied.
function Wall.damage(combat, wall, amount)
    if not wall.alive then return 0 end
    wall.health = wall.health - amount
    if wall.health <= 0 then destroy(combat, wall) end
    return amount
end

-- Tear down every `illusion`-tagged wall whose tile is in `cells` (Dispel Illusions). Returns the
-- number destroyed.
function Wall.dispelIn(combat, cells)
    local n = 0
    for _, c in ipairs(cells or {}) do
        local w = Wall.at(combat, c.x, c.y)
        if w then
            for _, t in ipairs(w.tags or {}) do
                if t == "illusion" then
                    destroy(combat, w, string.format("%s is dispelled.", w.name or "The wall"))
                    n = n + 1
                    break
                end
            end
        end
    end
    return n
end

-- Count timed walls down by `elapsed` ticks; fade any whose time is up. Called from Combat.rebase
-- with the ticks that just elapsed, beside Status.tick / Hazard.tick.
function Wall.tick(combat, elapsed)
    if not elapsed or elapsed <= 0 then return end
    for _, w in ipairs(combat.walls or {}) do
        if w.alive and w.remaining then
            w.remaining = w.remaining - elapsed
            if w.remaining <= 0 then destroy(combat, w, string.format("%s fades.", w.name or "The wall")) end
        end
    end
end

return Wall
