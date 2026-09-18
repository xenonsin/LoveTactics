-- VAULTS: the authored things a rolled floor is made of (Overworld:placeVaults, data/vaults/).
--
-- The bet, stated once: a generated floor can still be built out of pieces somebody wrote. The seed
-- still decides the floor -- which vault, and where -- so two saves get different floors and one save
-- gets the same floor forever. What changes is that the pieces have intent in them.
--
-- FOUR THINGS CAN ROT HERE, and three of them are silent:
--
--   * a vault strands part of the board, which the hollow pass exists to prevent and which no player
--     could diagnose -- they would just find a cache they cannot walk to
--   * the generator seats a rolled stop inside one, which is the generator talking over the author
--   * a vault swallows the way in, the way out or the floor's own end
--   * the same seed lays a different floor twice, which breaks the kept map outright

local Overworld = require("models.overworld")
local Descent = require("models.descent")
local Player = require("models.player")

local function floorWith(seed, vaults)
    return Overworld.generate({
        biome = "forest", cols = 13, rows = 13, seed = seed,
        encounterCount = 12, cacheCount = 3, keyCount = 0, ascent = true, secrets = true,
        vaultCount = vaults,
        trapCount = { min = 0, max = 0 },
        encounters = { { kind = "combat", weight = 1 } },
    })
end

local function vaultCells(grid)
    local out = {}
    for y = 1, grid.rows do
        for x = 1, grid.cols do
            if grid.cells[y][x].vault then out[#out + 1] = grid.cells[y][x] end
        end
    end
    return out
end

return {
    { name = "a vault is a data file, and the library is whatever is in the folder", fn = function()
        -- X-2: adding a set-piece has to be a file and nothing else, or the library stops at whatever
        -- shipped on day one.
        local n = 0
        for id, def in pairs(Overworld.vaults or {}) do
            n = n + 1
            assert(type(def.map) == "table" and #def.map > 0, id .. " has no map block")
            local w = #def.map[1]
            for i, row in ipairs(def.map) do
                assert(#row == w, id .. " row " .. i .. " is " .. #row .. " wide, not " .. w
                    .. " -- a ragged map stamps a ragged hole")
            end
            -- Every numbered cell must name a content entry, or the author wrote a reward that is not
            -- there and nothing would ever say so.
            for _, row in ipairs(def.map) do
                for i = 1, #row do
                    local k = tonumber(row:sub(i, i))
                    if k then
                        assert(def.contents and def.contents[k],
                            id .. " marks a cell " .. k .. " with no contents[" .. k .. "] behind it")
                    end
                end
            end
        end
        assert(n > 0, "the vault folder is empty, so placeVaults can never do anything")
    end },

    { name = "a floor lays the vaults it was asked for, and none when nobody asked", fn = function()
        assert(#vaultCells(floorWith(4242, nil)) == 0,
            "a board that never mentioned vaults grew one -- every authored quest would sprout rooms")
        assert(#vaultCells(floorWith(4242, { min = 0, max = 0 })) == 0,
            "a floor asked for no vaults laid one")

        local withVault = 0
        for seed = 1, 30 do
            if #vaultCells(floorWith(seed, { min = 1, max = 1 })) > 0 then withVault = withVault + 1 end
        end
        assert(withVault > 0, "no seed in 30 could place a vault; the pass never fires")
    end },

    { name = "A VAULT NEVER STRANDS THE FLOOR", fn = function()
        -- The one that no player could diagnose: they would simply find a cache they cannot walk to.
        -- placeVaults refuses a stamp that breaks connectivity rather than carving its way out.
        for seed = 1, 60 do
            local grid = floorWith(seed, { min = 1, max = 1 })
            local dist = grid:bfsDistances(grid:startCell())
            for y = 1, grid.rows do
                for x = 1, grid.cols do
                    local c = grid.cells[y][x]
                    if grid:typeWalkable(c.tile) then
                        assert(dist[c.y * 100000 + c.x],
                            "seed " .. seed .. ": (" .. x .. "," .. y .. ") is walkable and unreachable")
                    end
                end
            end
        end
    end },

    { name = "nothing rolled is ever seated inside one", fn = function()
        -- A-3. A merchant in the middle of the ring is the generator talking over the author, and the
        -- shape is only worth authoring if it survives the passes that come after it.
        local checked = 0
        for seed = 1, 40 do
            local grid = floorWith(seed, { min = 1, max = 1 })
            for _, c in ipairs(vaultCells(grid)) do
                checked = checked + 1
                assert(not c.cache, "seed " .. seed .. ": a cache was seated inside a vault")
                assert(not c.gate and not c.key, "seed " .. seed .. ": a lock was seated inside a vault")
                assert(not c.secret, "seed " .. seed .. ": a secret was cut into a vault")
                -- An encounter here is legal ONLY if the author put it there.
                if c.encounter then
                    local authored = false
                    for _, def in pairs(Overworld.vaults) do
                        for _, content in ipairs(def.contents or {}) do
                            if content.name == c.encounter.name then authored = true end
                        end
                    end
                    assert(authored, "seed " .. seed .. ": a rolled "
                        .. tostring(c.encounter.kind) .. " was seated inside a vault")
                end
            end
        end
        assert(checked > 0, "no vault cells in 40 seeds; this case proved nothing")
    end },

    { name = "a vault never swallows the way in, the way out or the floor's own end", fn = function()
        for seed = 1, 60 do
            local grid = floorWith(seed, { min = 1, max = 1 })
            local start = grid:startCell()
            assert(not start.vault, "seed " .. seed .. ": a vault swallowed the tile they walk in on")
            if grid.objective then
                local o = grid.cells[grid.objective.y][grid.objective.x]
                assert(not o.vault, "seed " .. seed .. ": a vault swallowed the stair")
            end
        end
    end },

    { name = "the same seed lays the same floor, vault and all", fn = function()
        -- The kept map rests on this entirely (Descent.keepFloor): floor three of one save has to be
        -- floor three of that save forever, which means every deal in the generator -- this one
        -- included -- must come off the seed and never off math.random.
        for _, seed in ipairs({ 7, 101, 5150 }) do
            local a, b = floorWith(seed, { min = 1, max = 1 }), floorWith(seed, { min = 1, max = 1 })
            local ca, cb = vaultCells(a), vaultCells(b)
            assert(#ca == #cb, "seed " .. seed .. " laid " .. #ca .. " vault cells then " .. #cb)
            for i = 1, #ca do
                assert(ca[i].x == cb[i].x and ca[i].y == cb[i].y,
                    "seed " .. seed .. " put the vault somewhere else the second time")
            end
        end
    end },

    { name = "every descent floor asks for a vault", fn = function()
        -- The wiring question, asked of floorQuest rather than of the generator -- which is the lesson
        -- tests/side_gate_spec.lua learned the hard way: a param added to one of floorQuest's two map
        -- blocks reaches one floor in fifteen, and a spec driving Overworld.generate cannot see it.
        local player = Player.new()
        local run = Descent.new(player, 2024)
        for floor = 1, Descent.FLOORS do
            run.floor = floor
            assert(Descent.floorQuest(run, player).map.vaultCount,
                "floor " .. floor .. " asks for no vault")
        end
    end },
}
