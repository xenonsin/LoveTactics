-- The fights that walk (models/patrol.lua, Overworld:placePatrols). These pin the rules the board's
-- whole contract rests on: a patrol is never faster than the party, a guard cannot wander off the thing
-- it guards, and a loose one never strays onto the road to the objective.

local Overworld = require("models.overworld")
local Patrol = require("models.patrol")

local function board(seed)
    return Overworld.generate({
        biome = "forest", seed = seed or 4242,
        encounterCount = 10, keyCount = 1,
        objective = { name = "Boss" },
        houseMaterial = "material_iron",
        patrols = true,
        encounters = {
            { kind = "combat", weight = 4 }, { kind = "elite", weight = 1 },
            { kind = "treasure", weight = 2 }, { kind = "rest", weight = 1 },
        },
    })
end

local function key(x, y) return y * 100000 + x end

return {
    {
        name = "patrols: the fight count is untouched -- fights are lifted, never minted or lost",
        fn = function()
            for seed = 1, 6 do
                local still = Overworld.generate({
                    biome = "forest", seed = seed * 17, encounterCount = 10, keyCount = 1,
                    objective = { name = "Boss" }, houseMaterial = "material_iron",
                    encounters = { { kind = "combat", weight = 4 }, { kind = "elite", weight = 1 },
                                   { kind = "treasure", weight = 2 }, { kind = "rest", weight = 1 } },
                })
                local walking = Overworld.generate({
                    biome = "forest", seed = seed * 17, encounterCount = 10, keyCount = 1,
                    objective = { name = "Boss" }, houseMaterial = "material_iron", patrols = true,
                    encounters = { { kind = "combat", weight = 4 }, { kind = "elite", weight = 1 },
                                   { kind = "treasure", weight = 2 }, { kind = "rest", weight = 1 } },
                })
                local function fights(grid)
                    local n = 0
                    for y = 1, grid.rows do
                        for x = 1, grid.cols do
                            local e = grid.cells[y][x].encounter
                            if e and (e.kind == "combat" or e.kind == "elite") then n = n + 1 end
                        end
                    end
                    for _, p in ipairs(grid.patrols or {}) do
                        local k = p.encounter and p.encounter.kind
                        if k == "combat" or k == "elite" then n = n + 1 end
                    end
                    return n
                end
                assert(fights(still) == fights(walking), string.format(
                    "seed %d: %d fights standing, %d once some walk", seed, fights(still), fights(walking)))
            end
        end,
    },
    {
        name = "patrols: a guard's beat is its cut set -- it can never step off what it guards",
        fn = function()
            -- THE INVARIANT THE OFFER RULE DEPENDS ON. guardBoons seats a fight on a tile that provably
            -- gates a reward; let that fight wander freely and the guarantee evaporates. So for every
            -- guard, for every tile on its beat, the boon must still be unreachable with that tile
            -- blocked -- checked here by walking the board, exactly as the generator checks it.
            local checked = 0
            for seed = 1, 6 do
                local grid = board(seed * 31)
                for _, p in ipairs(grid.patrols or {}) do
                    if p.guards then
                        local boon = grid:get(p.guards.x, p.guards.y)
                        for _, tile in ipairs(p.beat) do
                            local blocked = grid:get(tile.x, tile.y)
                            local start = grid:startCell()
                            local seen, q, qi = { [key(start.x, start.y)] = true }, { start }, 1
                            local reached = false
                            while qi <= #q and not reached do
                                local c = q[qi]; qi = qi + 1
                                for _, n in ipairs(grid:pathNeighbors(c.x, c.y)) do
                                    if n == boon then reached = true break end
                                    if not seen[key(n.x, n.y)] and n ~= blocked then
                                        seen[key(n.x, n.y)] = true
                                        q[#q + 1] = n
                                    end
                                end
                            end
                            assert(not reached, string.format(
                                "seed %d: a guard standing at (%d,%d) does not gate its boon",
                                seed * 31, tile.x, tile.y))
                            checked = checked + 1
                        end
                    end
                end
            end
            assert(checked > 0, "expected at least one guard on a beat across six boards")
        end,
    },
    {
        name = "patrols: a loose beat never touches the road to the objective",
        fn = function()
            -- Combat is kept off the spine so a wounded company can always route to the boss. A patrol
            -- that wandered onto it would undo that silently -- and unlike a seated fight, nothing would
            -- ever show it had. Alert is allowed to cross; a BEAT is not.
            for seed = 1, 6 do
                local grid = board(seed * 7)
                for _, p in ipairs(grid.patrols or {}) do
                    if not p.guards then
                        for _, tile in ipairs(p.beat) do
                            assert(not grid.spineKeys[key(tile.x, tile.y)], string.format(
                                "seed %d: a loose patrol beats across the objective road at (%d,%d)",
                                seed * 7, tile.x, tile.y))
                        end
                    end
                end
            end
        end,
    },
    {
        name = "patrols: never faster than the party, and every beat tile is walkable",
        fn = function()
            for seed = 1, 6 do
                local grid = board(seed * 11)
                for _, p in ipairs(grid.patrols or {}) do
                    -- Pace is a DIVISOR on the tick, so 1 is every step and 2 is every other. Below 1
                    -- would mean more than one tile per player step, which is the one thing that would
                    -- let a patrol corner a company in open corridor.
                    assert(p.pace >= 1, "a patrol may never move more than one tile per player step")
                    for _, tile in ipairs(p.beat) do
                        assert(grid:typeWalkable(grid:get(tile.x, tile.y).tile),
                            "a beat ran through a wall")
                    end
                end
            end
        end,
    },
    {
        name = "patrols: the telegraph does not move the thing it describes",
        fn = function()
            -- An intent preview that advanced the board would be a bug the player could farm by hovering.
            local grid = board(99)
            local p = (grid.patrols or {})[1]
            assert(p, "expected a patrol")
            local before = { x = p.x, y = p.y, i = p.i, dir = p.dir, state = p.state, alert = p.alert }
            for _ = 1, 5 do Patrol.preview(grid, p, { x = grid.start.x, y = grid.start.y }) end
            assert(p.x == before.x and p.y == before.y, "preview moved the patrol")
            assert(p.i == before.i and p.dir == before.dir, "preview advanced the beat")
            assert(p.state == before.state and p.alert == before.alert, "preview changed its state")
        end,
    },
    {
        name = "patrols: a beat walks its circuit and comes back, one tile at a time",
        fn = function()
            local grid = board(1234)
            local mover
            for _, p in ipairs(grid.patrols or {}) do
                if #p.beat > 2 and p.pace == 1 then mover = p break end
            end
            if not mover then return end -- a board of sentries is legal; nothing to assert
            local seen = {}
            local prev = { x = mover.x, y = mover.y }
            for _ = 1, 20 do
                -- Somewhere the patrol can never see, so it stays on its beat rather than giving chase.
                Patrol.tick(grid, { x = -50, y = -50 })
                local step = math.abs(mover.x - prev.x) + math.abs(mover.y - prev.y)
                assert(step <= 1, "a patrol moved more than one tile in a tick")
                seen[key(mover.x, mover.y)] = true
                prev = { x = mover.x, y = mover.y }
            end
            -- It stayed on its own beat the whole time.
            local beatKeys = {}
            for _, t in ipairs(mover.beat) do beatKeys[key(t.x, t.y)] = true end
            for k in pairs(seen) do
                assert(beatKeys[k], "a patrol on its beat wandered off it")
            end
        end,
    },
    {
        name = "patrols: a run remembers where they had got to",
        fn = function()
            local grid = board(555)
            local p = (grid.patrols or {})[1]
            assert(p, "expected a patrol")
            for _ = 1, 5 do Patrol.tick(grid, { x = -50, y = -50 }) end
            local restored = Overworld.fromSnapshot(grid:snapshot())
            assert(#restored.patrols == #grid.patrols, "a resumed run lost patrols")
            local q = restored.patrols[1]
            assert(q.x == p.x and q.y == p.y, "a resumed patrol went back to where it started")
            assert(q.state == p.state and q.i == p.i, "a resumed patrol forgot what it was doing")
            assert(#q.beat == #p.beat, "a resumed patrol forgot its beat")
        end,
    },
}
