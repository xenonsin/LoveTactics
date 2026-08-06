-- Tests for the guarded-boon pass (models/overworld.lua's Overworld:guardBoons).
--
-- The rule it enforces is the tile-level shape of the whole overworld decision: the objective is the
-- only fight the player MUST take, every other fight is optional, and an optional fight should be
-- attached to something worth having. A boon at the end of a spur, a fight in the corridor to it.
--
-- The interesting invariant is not "a fight sits nearby" -- it is that the fight is a genuine CUT
-- VERTEX, so the reward really is unreachable without clearing it. That is what walkWithout checks.

local Overworld = require("models.overworld")
local Tileset = require("models.tileset")

local function typeWalkable(tile)
    local def = Tileset.get().tiles[tile]
    return def ~= nil and def.walkable == true
end

local function gen(overrides)
    local params = {
        cols = 41, rows = 27, seed = 99, riverCount = 1,
        encounterCount = 8, keyCount = 0, objective = { name = "Boss" },
        houseMaterial = "material_bastion_steel",
        encounters = {
            { kind = "combat", weight = 4 },
            { kind = "elite", weight = 1 },
            { kind = "treasure", weight = 2 },
            { kind = "relic_cache", weight = 1 },
            { kind = "rest", weight = 1 },
            { kind = "merchant", weight = 1 },
        },
    }
    if overrides then
        for k, v in pairs(overrides) do params[k] = v end
    end
    return Overworld.generate(params)
end

local function eachCell(grid, fn)
    for y = 1, grid.rows do
        for x = 1, grid.cols do fn(grid:get(x, y), x, y) end
    end
end

-- Every guard on the board, as { guard = cell, boon = cell }.
local function pairsOf(grid)
    local out = {}
    eachCell(grid, function(c)
        if c.guards then
            out[#out + 1] = { guard = c, boon = grid:get(c.guards.x, c.guards.y) }
        end
    end)
    return out
end

local function isBoon(c)
    return c and (c.cache ~= nil
        or (c.encounter ~= nil and (c.encounter.kind == "treasure" or c.encounter.kind == "relic_cache")))
end

-- Reachable-from-start walk with one tile treated as impassable -- gates ignored, since what is under
-- test is the geometry, not the key system. Returns a set of "x,y" keys.
local function walkWithout(grid, blockX, blockY)
    local seen = {}
    local start = grid:startCell()
    if not start then return seen end
    local q, qi = { start }, 1
    seen[start.x .. "," .. start.y] = true
    while qi <= #q do
        local c = q[qi]; qi = qi + 1
        for _, n in ipairs(grid:pathNeighbors(c.x, c.y)) do
            local k = n.x .. "," .. n.y
            if not seen[k] and not (n.x == blockX and n.y == blockY) then
                seen[k] = true
                q[#q + 1] = n
            end
        end
    end
    return seen
end

return {
    { name = "a guard is a real gate: its boon is unreachable without crossing it", fn = function()
        -- Swept over many boards rather than one, because a cut vertex that holds on a single seed can
        -- easily be an accident of that seed's geometry.
        local checked = 0
        for seed = 1, 40 do
            local grid = gen({ seed = seed })
            for _, p in ipairs(pairsOf(grid)) do
                assert(p.boon, "a guard points at no boon (seed " .. seed .. ")")
                local reach = walkWithout(grid, p.guard.x, p.guard.y)
                assert(not reach[p.boon.x .. "," .. p.boon.y],
                    "boon at " .. p.boon.x .. "," .. p.boon.y .. " is reachable without its guard (seed " .. seed .. ")")
                checked = checked + 1
            end
        end
        assert(checked > 0, "no guarded boons were produced across 40 boards")
    end },

    { name = "what stands guard is always a fight, and what it guards is always a find", fn = function()
        for seed = 1, 40 do
            local grid = gen({ seed = seed })
            for _, p in ipairs(pairsOf(grid)) do
                local e = p.guard.encounter
                assert(e and (e.kind == "combat" or e.kind == "elite"),
                    "a guard is not a fight (seed " .. seed .. ")")
                assert(isBoon(p.boon), "a guard stands in front of something that is not a find (seed " .. seed .. ")")
            end
        end
    end },

    { name = "the services are never guarded -- a shop behind a fight is friction, a rest is the valve", fn = function()
        for seed = 1, 40 do
            local grid = gen({ seed = seed })
            for _, p in ipairs(pairsOf(grid)) do
                local k = p.boon.encounter and p.boon.encounter.kind
                assert(k ~= "rest" and k ~= "merchant" and k ~= "shrine" and k ~= "town",
                    "a service (" .. tostring(k) .. ") was guarded (seed " .. seed .. ")")
            end
        end
    end },

    { name = "no guard stands on the spine -- the walk to the objective stays fight-free", fn = function()
        for seed = 1, 40 do
            local grid = gen({ seed = seed })
            for _, p in ipairs(pairsOf(grid)) do
                assert(not (grid.spineKeys and grid.spineKeys[p.guard.x .. "," .. p.guard.y]),
                    "a guard was seated on the critical path (seed " .. seed .. ")")
            end
        end
    end },

    { name = "nearly every fight the board has is spent standing in front of something", fn = function()
        -- THE REAL INVARIANT, and not the one this spec was first written to check.
        --
        -- "Most boons are guarded" cannot be asserted from here, because it is not a property of this
        -- pass -- it is a property of the CONTENT MIX. A board carries roughly two and a half boons per
        -- fight (cacheTarget is half the encounter count, and the pool's finds take a further share of
        -- what is left after the combat cap), so even perfect deployment leaves most boons in the open.
        -- Moving that number means moving cacheTarget and combatShare, which changes what a run is worth
        -- and how much it costs -- a balance decision, deliberately not made here.
        --
        -- What guardBoons is answerable for is that it wastes nothing: if a fight exists and a reward
        -- can be gated by it, the two are paired. That is what this pins.
        local fights, guarded = 0, 0
        for seed = 1, 60 do
            local grid = gen({ seed = seed })
            eachCell(grid, function(c)
                local e = c.encounter
                if e and (e.kind == "combat" or e.kind == "elite") then fights = fights + 1 end
            end)
            guarded = guarded + #pairsOf(grid)
        end
        assert(fights > 0, "no fights on any board")
        local deployed = guarded / fights
        assert(deployed > 0.7, "fights are going spare instead of guarding: "
            .. string.format("%.2f", deployed))
        assert(deployed <= 1.0, "more guards than fights, which is impossible: "
            .. string.format("%.2f", deployed))
    end },

    { name = "some boons stay loose on the road -- the quota is a share, not a law", fn = function()
        local boons, guarded = 0, 0
        for seed = 1, 60 do
            local grid = gen({ seed = seed })
            eachCell(grid, function(c)
                if typeWalkable(c.tile) and isBoon(c) then boons = boons + 1 end
            end)
            guarded = guarded + #pairsOf(grid)
        end
        assert(boons > 0, "no boons on any board")
        local share = guarded / boons
        -- An unbroken "every reward has a guard" rule turns the map into a checklist; the loose
        -- remainder is deliberate. The floor is low because the mix, not this pass, sets the ceiling --
        -- see the previous case. Raise this when cacheTarget/combatShare are retuned.
        assert(share > 0.25, "almost nothing is guarded: " .. string.format("%.2f", share))
        assert(share < 0.95, "nearly every boon is guarded; the loose remainder is deliberate: "
            .. string.format("%.2f", share))
    end },

    { name = "guarding pays: a guarded cache is worth more than the detour alone earned it", fn = function()
        -- Same board, same geometry, read twice: the bonus is applied in place by guardBoons, so a
        -- guarded cache must out-pay the floor a cache can be authored at.
        local guardedTotal, looseTotal, guardedN, looseN = 0, 0, 0, 0
        for seed = 1, 40 do
            local grid = gen({ seed = seed })
            local guardedCells = {}
            for _, p in ipairs(pairsOf(grid)) do guardedCells[p.boon] = true end
            eachCell(grid, function(c)
                if c.cache and c.cache.materials then
                    local sum = 0
                    for _, n in pairs(c.cache.materials) do sum = sum + n end
                    if guardedCells[c] then guardedTotal = guardedTotal + sum; guardedN = guardedN + 1
                    else looseTotal = looseTotal + sum; looseN = looseN + 1 end
                end
            end)
        end
        assert(guardedN > 0, "no guarded caches across 40 boards")
        if looseN > 0 then
            assert(guardedTotal / guardedN > looseTotal / looseN,
                "a guarded cache does not out-pay a loose one; the fight is a tax, not a price")
        end
    end },

    { name = "seeing the guard reveals what it is for", fn = function()
        local grid = gen({ seed = 7 })
        local p = pairsOf(grid)[1]
        assert(p, "no guarded boon on this board")
        -- Wipe the fog, then light only the guard's own tile: the boon behind it must come with it, or
        -- the player meets a fight with no idea anything is past it.
        eachCell(grid, function(c) c.seen = nil end)
        grid:reveal(p.guard.x, p.guard.y, 0)
        assert(p.guard.seen, "the guard tile did not reveal")
        assert(p.boon.seen, "the boon behind the guard stayed under fog")
    end },

    { name = "an ascent map opts out -- there the fight IS the route", fn = function()
        local grid = gen({ seed = 3, ascent = true,
            alwaysEncounters = { { kind = "combat" }, { kind = "combat" }, { kind = "elite" } } })
        assert(#pairsOf(grid) == 0, "an ascent board seated guards")
    end },

    { name = "a cramped board degrades quietly instead of failing", fn = function()
        -- The same graceful fallback placeKeys and placeCaches take: too little room simply pays out
        -- less. What must not happen is an error or a guard with nothing behind it.
        for seed = 1, 12 do
            local grid = gen({ seed = seed, cols = 15, rows = 11, encounterCount = 2 })
            for _, p in ipairs(pairsOf(grid)) do
                assert(p.boon, "a guard points at no boon on a cramped board (seed " .. seed .. ")")
            end
        end
    end },

    { name = "the encounter count is untouched: guards are moved, never minted", fn = function()
        -- guardBoons re-seats fights that are already on the board. If it ever added one, the map's
        -- sizing (deriveDims) and the quest's authored pool would both quietly stop meaning anything.
        for seed = 1, 20 do
            local grid = gen({ seed = seed, encounterCount = 8 })
            local fights = 0
            eachCell(grid, function(c)
                local e = c.encounter
                if e and (e.kind == "combat" or e.kind == "elite") then fights = fights + 1 end
            end)
            local total = 0
            eachCell(grid, function(c) if c.encounter then total = total + 1 end end)
            assert(total <= 8 + 1, "more stops than the board was sized for (seed " .. seed .. "): " .. total)
            assert(fights > 0, "no fights at all on seed " .. seed)
        end
    end },
}
