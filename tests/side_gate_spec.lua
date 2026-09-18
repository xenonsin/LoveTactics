-- A SIDE ROUTE BEHIND A LOCK (Overworld:placeSideGates, Descent.FLOOR_SIDE_GATES).
--
-- The gate machinery has existed and been switched off since the descent was written, because
-- Overworld:chokeAndGate locks the road to the OBJECTIVE and "a floor is not a lock puzzle: the stair
-- is always reachable". That rule is not being reversed. This pass locks a SPUR instead.
--
-- Three things can rot here and every one of them is invisible in play until it is infuriating:
--
--   * the stair ends up behind the key, and a company without it cannot leave the floor
--   * the key ends up behind its own gate, which is the same thing wearing a better disguise
--   * the gate shuts an empty spur, which teaches the player that doors are not worth the walk
--
-- All three are asked directly here rather than inferred, because all three are cheap to ask and
-- expensive to discover.

local Overworld = require("models.overworld")
local Descent = require("models.descent")

local function floorWith(seed, gates, opts)
    opts = opts or {}
    return Overworld.generate({
        biome = "forest", cols = 13, rows = 13, seed = seed,
        encounterCount = opts.encounters or 10,
        cacheCount = opts.caches or 3,
        keyCount = 0, ascent = true, secrets = true,
        sideGateCount = gates,
        trapCount = { min = 0, max = 0 },
        encounters = { { kind = "combat", weight = 1 } },
    })
end

-- Every cell the company can reach from the door, with `shut` treated as a wall.
local function reachableWith(grid, shut)
    local seen, queue = {}, { grid:startCell() }
    local function key(c) return c.y * 1000 + c.x end
    seen[key(queue[1])] = true
    local i = 1
    while i <= #queue do
        local c = queue[i]; i = i + 1
        for _, n in ipairs(grid:pathNeighbors(c.x, c.y)) do
            local blocked = false
            for _, s in ipairs(shut or {}) do if s == n then blocked = true end end
            if not blocked and not seen[key(n)] then
                seen[key(n)] = true
                queue[#queue + 1] = n
            end
        end
    end
    return seen, key
end

local function gatesOf(grid)
    local out = {}
    for y = 1, grid.rows do
        for x = 1, grid.cols do
            if grid.cells[y][x].gate then out[#out + 1] = grid.cells[y][x] end
        end
    end
    return out
end

local function keysOf(grid)
    local out = {}
    for y = 1, grid.rows do
        for x = 1, grid.cols do
            if grid.cells[y][x].key then out[#out + 1] = grid.cells[y][x] end
        end
    end
    return out
end

return {
    { name = "a floor lays the gates it was asked for, and none when nobody asked", fn = function()
        assert(#gatesOf(floorWith(4242, nil)) == 0,
            "a board that never mentioned side gates grew one -- every authored quest would sprout locks")
        assert(#gatesOf(floorWith(4242, { min = 0, max = 0 })) == 0,
            "a floor asked for no gates laid one anyway")

        -- Not every seed can offer a legal gate -- a floor with no spur worth shutting correctly lays
        -- none -- so this is measured over a run of seeds rather than asserted on one.
        local withGate = 0
        for seed = 1, 40 do
            if #gatesOf(floorWith(seed, { min = 1, max = 1 })) > 0 then withGate = withGate + 1 end
        end
        assert(withGate > 0, "no seed in 40 could seat a side gate; the pass never fires")
    end },

    { name = "THE STAIR IS NEVER BEHIND THE KEY", fn = function()
        -- The one promise that matters. A company that cannot reach the stair cannot leave the floor,
        -- and on a fifteen-floor stack that is the worst bug this generator could ship.
        local checked = 0
        for seed = 1, 60 do
            local grid = floorWith(seed, { min = 1, max = 1 })
            local gates = gatesOf(grid)
            if #gates > 0 then
                checked = checked + 1
                local seen, key = reachableWith(grid, gates)
                assert(grid.objective, "the fixture floor has no objective to protect")
                assert(seen[key(grid.objective)],
                    "seed " .. seed .. ": the stair is unreachable with the gate shut")
                -- ...and the way out, which on a descent floor stands on the tile they walked in on.
                assert(seen[key(grid:startCell())], "seed " .. seed .. ": the way out is gated")
            end
        end
        assert(checked > 0, "no floor in 60 seeds laid a gate; this case proved nothing")
    end },

    { name = "the key is never behind its own gate", fn = function()
        local checked = 0
        for seed = 1, 60 do
            local grid = floorWith(seed, { min = 1, max = 1 })
            local gates = gatesOf(grid)
            if #gates > 0 then
                checked = checked + 1
                local seen, key = reachableWith(grid, gates)
                for _, k in ipairs(keysOf(grid)) do
                    assert(seen[key(k)],
                        "seed " .. seed .. ": a key sits behind the gate it opens, which locks the "
                        .. "spur for good")
                end
            end
        end
        assert(checked > 0, "no floor in 60 seeds laid a gate; this case proved nothing")
    end },

    { name = "what a gate shuts is worth having, and is never most of the floor", fn = function()
        local checked = 0
        for seed = 1, 60 do
            local grid = floorWith(seed, { min = 1, max = 1 })
            local gates = gatesOf(grid)
            if #gates > 0 then
                checked = checked + 1
                local seen, key = reachableWith(grid, gates)
                local cut, prize = 0, false
                for y = 1, grid.rows do
                    for x = 1, grid.cols do
                        local c = grid.cells[y][x]
                        if c ~= gates[1] and grid:typeWalkable(c.tile) and not seen[key(c)] then
                            cut = cut + 1
                            if c.cache or c.encounter or c.secret then prize = true end
                        end
                    end
                end
                assert(prize, "seed " .. seed .. ": the gate shuts an empty spur -- a door with nothing "
                    .. "behind it teaches that doors are not worth the walk")
                assert(cut <= math.floor(grid:walkableTotal() * 0.35),
                    "seed " .. seed .. ": the gate shuts " .. cut .. " of " .. grid:walkableTotal()
                    .. " places -- that is the critical path wearing a side route's clothes")
            end
        end
        assert(checked > 0, "no floor in 60 seeds laid a gate; this case proved nothing")
    end },

    { name = "a descent floor asks for one lock and leaves keyCount alone", fn = function()
        -- keyCount gates the OBJECTIVE and stays off; this is the separate dial.
        assert(Descent.FLOOR_SIDE_GATES.min >= 1, "a floor that can roll no lock has no errand to leave")
        assert(Descent.FLOOR_SIDE_GATES.max <= 2,
            "at " .. Descent.FLOOR_SIDE_GATES.max .. " locks a floor the player stops reading a door "
            .. "as an event and starts reading it as a tax on carrying the right key")
    end },
}
