-- MOST OF A FLOOR'S FIGHTS STAND IN THE ONLY WAY TO SOMETHING.
--
-- THE COMPLAINT THIS ANSWERS, in the player's words: "I can reveal the entire map then selectively
-- choose what to encounter." Every stop on a grid of places is optional by construction -- a cell holds
-- one thing and you step onto it or you do not -- so a floor whose fights are scattered on open ground
-- is a shopping list, and reading the map is the only skill it asks for.
--
-- The board this replaced had a pass for it (`guardBoons`) and it went with the carve, on the argument
-- that a fight pays for itself in spoils and levels. True, and not enough: a fight that pays for itself
-- is a fight you take when you feel like it.
--
-- IT WAS NEVER A SUPPLY PROBLEM, which is the thing worth writing down. `. board-report` says a floor
-- offers about FOURTEEN places that are the only way to something, and before this pass fights stood on
-- 6% of them. The chokepoints were always there; nothing was being seated on them. That is the same
-- diagnosis the guarded-boon knob got wrong for a whole pass in the other direction, and the only reason
-- it was cheap to get right this time is that the instrument reports the supply and the take separately.

local Overworld = require("models.overworld")

local POOL = { { kind = "combat", weight = 3 }, { kind = "treasure", weight = 1 } }

local function floor(seed, overrides)
    local params = {
        cols = 10, rows = 10, seed = seed, biome = "underworld",
        encounterCount = { min = 11, max = 11 },
        encounters = POOL,
        objective = { name = "The Stair" },
        houseMaterial = "material_salt_iron",
        ascent = true, -- what a descent floor passes: combat IS the route down here
    }
    for k, v in pairs(overrides or {}) do params[k] = v end
    return Overworld.generate(params)
end

-- Does taking this place away put anything out of reach?
local function stranded(grid, c)
    local total = 0
    for y = 1, grid.rows do
        for x = 1, grid.cols do
            if grid:typeWalkable(grid.cells[y][x].tile) then total = total + 1 end
        end
    end
    local was = c.tile
    c.tile = "thicket"
    local reach = grid:reachable(grid:startCell())
    c.tile = was
    local n = 0
    for _ in pairs(reach) do n = n + 1 end
    return total - 1 - n
end

local function fights(grid)
    local all, blocking = {}, {}
    for y = 1, grid.rows do
        for x = 1, grid.cols do
            local c = grid.cells[y][x]
            local e = c.encounter
            if e and (e.kind == "combat" or e.kind == "elite") then
                all[#all + 1] = c
                if stranded(grid, c) > 0 then blocking[#blocking + 1] = c end
            end
        end
    end
    return all, blocking
end

return {
    {
        name = "most of a floor's fights are the only way to something",
        fn = function()
            local total, blocked = 0, 0
            for seed = 1, 20 do
                local grid = floor(seed)
                local all, blocking = fights(grid)
                total = total + #all
                blocked = blocked + #blocking
            end
            assert(total > 0, "the fixture floors hold no fights at all")
            local share = blocked / total
            -- Measured at 67% against Overworld.BLOCKING_SHARE of 0.6; the floor is well under that so a
            -- retune of the share does not have to come and edit this, and well over the 17% the floor
            -- produced when nothing was seating them.
            assert(share >= 0.45, string.format(
                "only %.0f%% of fights block anything (%d of %d) -- the floor is a shopping list again",
                share * 100, blocked, total))
        end,
    },
    {
        name = "it moves fights, it does not add them",
        fn = function()
            -- The floor's fight budget is authored (Descent.FLOOR_FIGHTS) and a pass that seated extra
            -- fights to make a point would quietly re-price the whole sitting. Same seed, pass on and
            -- off: the count must not move.
            for seed = 1, 10 do
                local on = select(1, fights(floor(seed)))
                local off = select(1, fights(floor(seed, { blockRoutes = false })))
                assert(#on == #off, string.format(
                    "seed %d: %d fights with the pass, %d without -- it is adding, not moving",
                    seed, #on, #off))
            end
        end,
    },
    {
        name = "a blocking fight never buries what it is blocking",
        fn = function()
            -- A fight seated on a cache would swallow the reward it was meant to stand in front of, and
            -- one seated on an end would be two fights on a cell that can only open one.
            for seed = 1, 20 do
                local grid = floor(seed)
                local _, blocking = fights(grid)
                for _, c in ipairs(blocking) do
                    assert(not c.cache, "seed " .. seed .. ": a fight is standing on a cache")
                    assert(not c.gate and not c.key,
                        "seed " .. seed .. ": a fight is standing on the lock chain")
                    assert(c.encounter.kind ~= "objective", "seed " .. seed .. ": doubled up on an end")
                    assert(not (grid.start.x == c.x and grid.start.y == c.y),
                        "seed " .. seed .. ": a fight is standing on the way in")
                end
            end
        end,
    },
    {
        name = "a fight can never pen the company in at the door",
        fn = function()
            -- THE FLOOR THIS CASE EXISTS FOR: a company steps off the stair and the one place it can go
            -- holds a battle. Nothing has been chosen -- not the route, not the fight, not whether the
            -- party is in any shape for it -- and on a floor whose whole design is routing around
            -- fights, the routing has to exist before the first fight does.
            --
            -- IT WAS CAUSED BY THE PASS ABOVE, which is why it is asserted here. :blockRoutes sorts its
            -- chokepoints by how much they hold back, and the cell that holds back the most is the mouth
            -- of the pocket the door sits in -- so "most stranded first" reached for the door every
            -- time. Measured: three floors in four opened penned, against 13% before the pass existed.
            -- Two rules answer it: no single fight may gate more than half the floor
            -- (Overworld.MAX_GATED), and the floor is checked as a whole afterwards
            -- (Overworld:freeTheDoor), which takes fights back off chokepoints until the door breathes.
            local worst = math.huge
            for seed = 1, 30 do
                local grid = floor(seed)
                local total = 0
                for y = 1, grid.rows do
                    for x = 1, grid.cols do
                        if grid:typeWalkable(grid.cells[y][x].tile) then total = total + 1 end
                    end
                end

                -- Walk from the door, refusing every battle.
                local start = grid:startCell()
                local function isFight(c)
                    local e = c and c.encounter
                    return (e and not c.cleared and (e.kind == "combat" or e.kind == "elite"
                        or e.kind == "objective")) or false
                end
                local seen = { [start.y * 100000 + start.x] = true }
                local q, qi, n = { start }, 1, 1
                while qi <= #q do
                    local c = q[qi]; qi = qi + 1
                    for _, nb in ipairs(grid:pathNeighbors(c.x, c.y)) do
                        local k = nb.y * 100000 + nb.x
                        if not seen[k] and not isFight(nb) then
                            seen[k] = true; n = n + 1; q[#q + 1] = nb
                        end
                    end
                end
                worst = math.min(worst, n / total)
                assert(n >= math.max(2, math.floor(total * Overworld.MIN_FREE_AT_DOOR)), string.format(
                    "seed %d: only %d of %d places can be reached without a fight -- the door is penned",
                    seed, n, total))
            end
            -- Measured at 73% of the floor free on the average roll; the bar above is a quarter, so this
            -- is nowhere near it and a retune of the blocking share will not quietly walk into it.
            assert(worst > 0, "at least some of every floor is reachable unfought")
        end,
    },
    {
        name = "a campaign ground keeps its open road; only a descent blocks it",
        fn = function()
            -- THE PILLAR THIS PASS IS NOT ALLOWED TO BREAK. On a campaign ground the objectives are the
            -- only fights you must take, so combat stays off the spine and a wounded company can always
            -- route to an end -- see docs/overworld.md's contract. A descent floor sets `ascent`, where
            -- combat IS the route, and that is the ONLY place a fight may sit across the way down.
            -- `ascent = false`, NOT nil: `{ ascent = nil }` is an empty table in Lua, so an override
            -- spelled that way silently leaves the fixture's own `ascent = true` in place and this case
            -- measures a descent floor while claiming to measure a campaign one. It did, and reported a
            -- pillar broken that was never touched.
            for seed = 1, 20 do
                local grid = floor(seed, { ascent = false })
                local _, blocking = fights(grid)
                for _, c in ipairs(blocking) do
                    assert(not (grid.spineKeys and grid.spineKeys[c.y * 100000 + c.x]),
                        "seed " .. seed .. ": a campaign ground put a fight across the road to its end")
                end
            end
        end,
    },
}
