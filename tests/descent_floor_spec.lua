-- Tests for what a descent floor is made of beyond its stops: the three hazards, and the doors that read
-- as wall until somebody looks.
--
-- Both are scoped to the descent and BOTH SCOPING RULES ARE ASSERTED HERE, in each direction. A hazard
-- that leaked onto a campaign board would be a stretch of dungeon dark laid across open country; a
-- secret on one would be content the player walks past once and never sees again, since a
-- campaign ground is walked once and left. The inverse cases are the ones that catch a regression,
-- because the feature working is visible in play and the leak is not.

local Descent = require("models.descent")
local Encounter = require("models.encounter")
local Overworld = require("models.overworld")
local Player = require("models.player")

local function floorGrid(seed, opts)
    local run = Descent.new(Player.new(), 909)
    run.floor = (opts and opts.floor) or 1
    local mp = Descent.floorQuest(run, Player.new()).map
    return Overworld.generate({
        biome = mp.biome, cols = mp.cols, rows = mp.rows,
        seed = seed, ascent = true, keyCount = 0,
        encounterCount = mp.encounters, cacheCount = mp.cacheCount,
        encounters = { { kind = "combat", weight = 3 }, { kind = "treasure", weight = 1 } },
        secrets = mp.secrets, exitAtStart = mp.exitAtStart,
        -- Passed because the FLOOR asks for it. Leaving it off here would build a floor the descent
        -- never rolls, and every case below would be measuring a fiction: the kinds a floor pins, and
        -- how many of each.
        guaranteeKinds = mp.guaranteeKinds,
        guarantee = mp.guarantee,
    }), mp
end

local function countKind(grid, kind)
    local n = 0
    for y = 1, grid.rows do
        for x = 1, grid.cols do
            local e = grid.cells[y][x].encounter
            if e and e.kind == kind then n = n + 1 end
        end
    end
    return n
end

return {
    { name = "the three hazards are authored inert and given weight only by a descent", fn = function()
        -- The scoping rule, from both ends. Each blueprint is authored at weight 0 so the campaign's own
        -- pool cannot produce one; Descent.floorPool is what gives them a weight, and it is the only
        -- thing that does.
        for _, h in ipairs(Descent.HAZARDS) do
            local def = Encounter.get(h.id)
            assert(def, h.id .. " names a blueprint that does not exist")
            assert((def.weight or 0) == 0,
                h.id .. " has a weight of its own -- it would roll onto campaign boards")
            assert(h.weight > 0, h.id .. " is in the descent's table with no weight, so it never seats")
        end

        -- ...and none of them is in a campaign board's pool, asked through the real seam.
        local hazard = {}
        for _, h in ipairs(Descent.HAZARDS) do hazard[h.id] = true end
        for _, biome in ipairs({ "forest", "swamp", "volcanic", "castle" }) do
            for _, e in ipairs(Encounter.pool({ biome = biome, day = 20, prestige = 10 })) do
                assert(not hazard[e.id], e.id .. " reached a campaign pool for " .. biome)
            end
        end

        -- ...and every one of them IS in a descent's.
        local seen = {}
        for _, e in ipairs(Descent.floorPool({ biome = "volcanic", day = 20, prestige = 10 })) do
            seen[e.id] = true
        end
        for _, h in ipairs(Descent.HAZARDS) do
            assert(seen[h.id], h.id .. " never reaches a descent floor's pool")
        end
    end },

    { name = "the hazard table is ordered, so a seed lays the same floor anywhere", fn = function()
        -- The generator draws stops in list order. A pool assembled by walking a keyed table with
        -- `pairs` would lay a DIFFERENT floor on the same seed on another machine -- the same rule
        -- Descent.SINS is ordered for, and the same failure: invisible until two people compare runs.
        for i, h in ipairs(Descent.HAZARDS) do
            assert(type(h) == "table" and h.id and h.weight,
                "hazard " .. i .. " is not an ordered { id, weight } entry")
        end
        local a = Descent.floorPool({ biome = "swamp", day = 5, prestige = 3 })
        local b = Descent.floorPool({ biome = "swamp", day = 5, prestige = 3 })
        assert(#a == #b, "the pool is a different length on two calls")
        for i = 1, #a do
            assert(a[i].id == b[i].id, "pool entry " .. i .. " moved between two calls")
        end
    end },

    { name = "a secret door hides its corridor from the fog until it is found", fn = function()
        -- The door is what stops the light. Lighting the door alone would put a lit stub of nothing in
        -- the middle of a wall, which is a worse tell than no secret at all -- so the whole run behind it
        -- stays black, and opening the door lets the fog through like any other trail.
        local found = 0
        for seed = 1, 8 do
            local grid = floorGrid(seed)
            local doors = {}
            for y = 1, grid.rows do
                for x = 1, grid.cols do
                    if grid.cells[y][x].secret then doors[#doors + 1] = grid.cells[y][x] end
                end
            end
            if #doors > 0 then
                found = found + #doors
                local door = doors[1]

                -- Standing right on top of it reveals nothing while it is still a wall.
                grid:reveal(door.x, door.y, 3)
                assert(not door.seen, "seed " .. seed .. ": a hidden door lit through the fog")

                -- ...and while it is hidden it is NOT a place, which is the whole of what makes it
                -- read as absent. On a board of tiles a secret was walkable ground behind a wall and
                -- only the fog hid it; on a grid there is no wall to hide behind, so the cell itself is
                -- the disguise -- finding it ADDS a place to the floor rather than opening a way into
                -- one that was already drawn (models/overworld.lua's placeSecrets).
                assert(not grid:typeWalkable(door.tile),
                    "seed " .. seed .. ": a hidden place is standing open")

                assert(grid:findSecrets(door.x, door.y, 1), "seed " .. seed .. ": the door is not findable")
                assert(not door.secret, "and finding it clears the mark")
                grid:reveal(door.x, door.y, 3)
                assert(door.seen, "seed " .. seed .. ": an opened door still will not light")
            end
        end
        assert(found > 0, "eight floors and not one secret door: they are not being dug")
    end },

    { name = "a secret is found by standing beside it, never at a distance", fn = function()
        -- The cost is having WALKED there, down a dead end that looked like it ended. A company that
        -- never goes down the spur never finds it, which is what makes exploring the reward rather than
        -- a roll -- and what stops searching becoming a chore performed against every wall.
        for seed = 1, 8 do
            local grid = floorGrid(seed)
            for y = 1, grid.rows do
                for x = 1, grid.cols do
                    if grid.cells[y][x].secret then
                        -- ASKED OF THIS DOOR, not of the sweep's return value. `findSecrets` answers
                        -- whether it found ANY door, and on a denser board (Descent.FLOOR_COLS) the tile
                        -- four away is often beside a different one -- so the old reading failed on a
                        -- search that had correctly found somebody else's secret and left this one shut.
                        grid:findSecrets(x + 4, y + 4, 1)
                        assert(grid.cells[y][x].secret,
                            "seed " .. seed .. ": this door was found from four tiles away")
                        assert(grid:findSecrets(x + 1, y, 1) or grid:findSecrets(x, y, 1),
                            "seed " .. seed .. ": a door beside the party was not found")
                        return
                    end
                end
            end
        end
    end },

    { name = "what a secret hides is a reward, and reachable once the door is open", fn = function()
        -- A hidden FIGHT would be content the player is likely never to see. A cache pays immediately on
        -- a tile nobody had to be persuaded onto, which is what makes the next dead end worth walking.
        for seed = 1, 8 do
            local grid = floorGrid(seed)
            local door
            for y = 1, grid.rows do
                for x = 1, grid.cols do
                    if grid.cells[y][x].secret then door = grid.cells[y][x] end
                end
            end
            if door then
                grid:findSecrets(door.x, door.y, 1)
                -- Walk the corridor the door opens and find what is at the end of it.
                local seen, q, qi, payload = { [door.y * grid.cols + door.x] = true }, { door }, 1, nil
                while qi <= #q do
                    local c = q[qi]; qi = qi + 1
                    if c.cache then payload = c end
                    for _, n in ipairs(grid:pathNeighbors(c.x, c.y)) do
                        local k = n.y * grid.cols + n.x
                        if not seen[k] then seen[k] = true; q[#q + 1] = n end
                    end
                end
                assert(payload, "seed " .. seed .. ": the hidden corridor pays nothing")
                return
            end
        end
    end },


    { name = "a campaign ground grows no hazards and no secrets", fn = function()
        -- The inverse, and the one that actually catches a regression: dungeon geography seated on open
        -- country, or ground a company walks past once and never sees.
        local grid = Overworld.generate({
            cols = 15, rows = 13, biome = "forest", seed = 5, encounterCount = { min = 8, max = 8 },
            encounters = Encounter.pool({ biome = "forest", day = 20, prestige = 10 }),
        })
        local hazard = {}
        for _, h in ipairs(Descent.HAZARDS) do hazard[Encounter.get(h.id).kind] = true end
        for y = 1, grid.rows do
            for x = 1, grid.cols do
                local c = grid.cells[y][x]
                assert(not c.secret, "a campaign ground hid a door at (" .. x .. "," .. y .. ")")
                assert(not (c.encounter and hazard[c.encounter.kind]),
                    "a campaign ground seated a descent hazard at (" .. x .. "," .. y .. ")")
            end
        end
    end },

    { name = "a found door survives the floor being put away and walked again", fn = function()
        -- `secret` is RUN STATE, not geometry: a door found on the third trip down must still be open on
        -- the fourth, and a company keeps its floors (Descent.keepFloor) precisely so that discovery
        -- persists. If it were left out of CELL_FIELDS every door would silently re-seal on re-entry.
        local Save = require("models.save")
        for seed = 1, 8 do
            local grid = floorGrid(seed)
            local door
            for y = 1, grid.rows do
                for x = 1, grid.cols do
                    if grid.cells[y][x].secret then door = grid.cells[y][x] end
                end
            end
            if door then
                local dx, dy = door.x, door.y
                grid:findSecrets(dx, dy, 1)
                local back = Overworld.fromSnapshot(
                    Save.decode("return " .. Save.encode(grid:snapshot(), 0)))
                assert(not back:get(dx, dy).secret,
                    "seed " .. seed .. ": a found door re-sealed when the floor was put away")

                -- ...and one still shut stays shut, or the round trip would be opening them all.
                local shut = floorGrid(seed)
                local other
                for y = 1, shut.rows do
                    for x = 1, shut.cols do
                        if shut.cells[y][x].secret then other = shut.cells[y][x] end
                    end
                end
                if other then
                    local shutBack = Overworld.fromSnapshot(
                        Save.decode("return " .. Save.encode(shut:snapshot(), 0)))
                    assert(shutBack:get(other.x, other.y).secret,
                        "seed " .. seed .. ": an unfound door opened itself across a save")
                end
                return
            end
        end
    end },

    { name = "beating the guardian opens the stair instead of taking it", fn = function()
        -- THE BUG THIS EXISTS TO STOP COMING BACK, and it was not a crash -- it was the floor being
        -- taken away from the player by the one fight they could not decline. Killing the stair's guard
        -- WAS the step down, so a party that met the objective early forfeited the floor's caches, its
        -- reliquary, its recruit and any errand a house had posted, and forfeited them to winning.
        --
        -- What the fix is, asserted at the seam the state calls: the tile stops being an objective and
        -- becomes a stop of its own, and -- the load-bearing half -- it comes back UNCLEARED, because
        -- ui/overworld_map.lua only fires onEncounter when arriving at a stop that is not cleared. A
        -- stair marked cleared would draw on the board, read as open, and answer nothing.
        local grid = floorGrid(3)
        local cell = grid:objectiveCell()
        assert(cell.encounter and cell.encounter.kind == "objective",
            "a floor's first end is not the objective this is written against")
        cell.cleared = true -- exactly what the win branch does before the landing runs

        assert(Descent.openStair(cell) == cell, "openStair did not answer with the tile it opened")
        assert(cell.encounter.kind == "stair", "the guardian's tile is still an objective")
        assert(not cell.cleared, "the stair opened cleared -- it can never be walked onto")
        assert(cell.encounter.name, "the stair has no name to draw or announce")

        -- ...and nothing without a tile, which is the resume path: a floor that comes back off disk
        -- already has its stair on the board and must not be handed a second one.
        assert(Descent.openStair(nil) == nil, "openStair invented a stair with no tile to open")
    end },

    { name = "an open stair survives the floor being put away and walked again", fn = function()
        -- A company that climbs out to the gate and comes back down gets the board it made
        -- (Descent.keepFloor). Its stair has to be part of that: the guard is dead, the circle is
        -- credited, and a floor that re-sealed its way down would be one the player could never leave
        -- except by climbing all the way back out.
        --
        -- Two halves, and the second is the one that would rot quietly: the encounter has to round-trip
        -- the save encoder, and Descent.rearmFloor -- which wakes a kept floor's fights -- has to leave
        -- it alone. rearmFloor re-arms by CLEARING the cleared flag, so a stair caught by it would look
        -- untouched while every other place on the floor had gone back to being spent.
        local Save = require("models.save")
        local grid = floorGrid(4)
        local cell = grid:objectiveCell()
        local sx, sy = cell.x, cell.y
        cell.cleared = true
        Descent.openStair(cell)

        local back = Overworld.fromSnapshot(Save.decode("return " .. Save.encode(grid:snapshot(), 0)))
        local kept = back:get(sx, sy)
        assert(kept.encounter and kept.encounter.kind == "stair",
            "the way down was lost when the floor was put away")
        assert(not kept.cleared, "the stair came back cleared and answers nothing")

        Descent.rearmFloor(back)
        assert(back:get(sx, sy).encounter.kind == "stair",
            "re-arming the floor's fights woke the stair guardian a second time")
    end },

    { name = "a floor holds one camp, however many stops it rolls", fn = function()
        -- The generator's rest guarantee is a DENSITY -- one per six stops -- and at a floor's 14-18 it
        -- laid down three. A camp hands back half of what is missing (Player.CAMP_SHARE), so three of
        -- them compound to about 53% of everything the floor cost, and fifteen floors of that is the
        -- free attrition CAMP_SHARE was cut to 0.5 to stop. A floor is a segment of a long run, not a
        -- run, so its camp count is flat. See Descent.FLOOR_RESTS.
        for seed = 1, 12 do
            local grid = floorGrid(seed)
            assert(countKind(grid, "rest") == Descent.FLOOR_RESTS, "seed " .. seed ..
                ": a floor laid down " .. countKind(grid, "rest") .. " camps, not " .. Descent.FLOOR_RESTS)
        end
    end },

    { name = "a campaign ground keeps the density the flat count was carved out of", fn = function()
        -- The inverse, and the case that catches the regression: pinning the floor must not reach the
        -- board a quest board's leg rolls. That board IS its run -- the party goes home from it and the
        -- hub makes them whole -- so how much refund it owes really does track how big it is, and it
        -- keeps asking for one per six stops.
        local Encounter = require("models.encounter")
        local seen = false
        for seed = 1, 12 do
            local grid = Overworld.generate({
                cols = 15, rows = 13, biome = "forest", seed = seed,
                encounterCount = { min = 11, max = 11 },
                encounters = Encounter.pool({ biome = "forest", day = 20, prestige = 10 }),
            })
            -- Eleven stops at one per six is two. A cramped board may seat fewer -- the guarantee takes
            -- the same silent partial fallback everywhere -- so this asserts the ceiling is still above
            -- one and that some board actually reaches it.
            local n = countKind(grid, "rest")
            assert(n <= 2, "seed " .. seed .. ": a campaign ground seated " .. n .. " rests")
            if n == 2 then seen = true end
        end
        assert(seen, "no campaign ground reached two rests -- the density knob has gone flat")
    end },

    { name = "every floor is at least as wide as the one above it, and the bottom is wider", fn = function()
        -- FOUR CELLS OF SPAN ACROSS FIFTEEN FLOORS, laid on alternating axes: 6x6 at the top and 8x8 at
        -- the bottom (Descent.floorDims).
        --
        -- The old claim here was STRICTLY bigger, floor by floor, and it was right for the board it was
        -- written against -- a tile a floor over a 40x40 rectangle is half a percent of the area, small
        -- enough to spend fifteen times. A cell on a 6x6 grid is nearly three percent of the floor AND a
        -- whole place besides, so a rung a floor would take the bottom to 20x20 and turn a sitting into
        -- an afternoon. The rate is four rungs held three or four floors each; what is asserted is that
        -- it never goes backwards, that it steps on an axis at a time, and that the bottom is a floor you
        -- can feel you walked down to.
        local cols, rows = Descent.floorDims(1)
        assert(cols == Descent.FLOOR_COLS and rows == Descent.FLOOR_ROWS,
            "floor 1 is not the grid the constants author -- the growth starts one floor too early")

        local pc, pr, rungs = cols, rows, 0
        for f = 2, Descent.FLOORS do
            local c, r = Descent.floorDims(f)
            assert(c >= pc and r >= pr,
                "floor " .. f .. " is narrower than floor " .. (f - 1) .. " on an axis")
            -- ONE AXIS AT A TIME, which is what keeps consecutive floors differently SHAPED (7x6 is not
            -- 6x7 to walk) and stops a rung landing as a jump.
            assert((c - pc) + (r - pr) <= 1,
                "floor " .. f .. " grew on both axes at once")
            if c * r > pc * pr then rungs = rungs + 1 end
            pc, pr = c, r
        end
        assert(rungs == 4, "the run should step four rungs, not " .. rungs)
        -- ...and the bottom is the widest ground in the game, by a margin worth having walked to. A
        -- third more places than the top, which on a grid is a dozen more somewheres.
        assert(pc * pr > cols * rows * 1.3,
            string.format("fifteen floors of growth only reached %dx%d from %dx%d -- the slope is too "
                .. "shallow to read over a run", pc, pr, cols, rows))
    end },

    { name = "the growth reaches the board, and the stop count climbs on its own terms", fn = function()
        -- Through the real descriptor, at three depths, and THE BOTTOM IS THE ONE THAT WOULD ROT: the
        -- Hollow Crown's floor is built by a second, separate branch of Descent.floorQuest with its own
        -- literal map table, so a size that only reached the sinned branch would leave the deepest floor
        -- in the game the size of the first.
        --
        -- THE SECOND HALF INVERTED, and the old claim is worth recording because it was half right. It
        -- read "the stop count does not follow it": a floor is a sitting, its deep fights are already the
        -- long ones, and stops scaled to the AREA would put floor 15 at twenty-seven of them. That much
        -- still holds and is what the assert below is really guarding -- the count is not a function of
        -- the rectangle. What was wrong was the conclusion drawn from it, that the count should therefore
        -- be flat: floor fifteen then laid out exactly as many fights as floor one on a board a third
        -- larger, and a number that never moves is a number the player stops reading. So it climbs, by an
        -- AUTHORED three over the whole run (Descent.FLOOR_FIGHTS_DEEP) rather than by anything the board
        -- can tell it. Re-derived from the floor and its ends here, so a ramp that started reading the
        -- dimensions would still fail this.
        local run = Descent.new(Player.new(), 909)
        for _, f in ipairs({ 1, Descent.CIRCLE_FLOORS, Descent.FLOORS }) do
            run.floor = f
            local mp = Descent.floorQuest(run, Player.new()).map
            local c, r = Descent.floorDims(f)
            assert(mp.cols == c and mp.rows == r, string.format(
                "floor %d is rolled on %dx%d, not the %dx%d its depth asks for", f, mp.cols, mp.rows, c, r))
            local want = Descent.floorBudget(#(mp.objectives or { mp.objective }), f)
            assert(mp.encounters.min == want.min and mp.encounters.max == want.max,
                "floor " .. f .. "'s stop count moved with its board")
            assert(mp.cacheCount.min == Descent.FLOOR_CACHES.min
                and mp.cacheCount.max == Descent.FLOOR_CACHES.max,
                "floor " .. f .. "'s cache count moved with its board")
        end
    end },

    { name = "the fight budget climbs with depth, steadily and by a little", fn = function()
        -- FOUR CLAIMS, and each is a different way the ramp could go wrong.
        --
        -- The first two are the shape the request named: it climbs, and it never turns back. A budget
        -- that dipped in the middle would be a bottom that asks for less than the floor above it, which
        -- is the one reading no player would accept.
        local prev = nil
        for f = 1, Descent.FLOORS do
            local n = Descent.floorFights(f)
            assert(not prev or n >= prev,
                string.format("floor %d holds %d fights against floor %d's %d -- the ramp runs backward",
                    f, n, f - 1, prev or 0))
            prev = n
        end
        assert(Descent.floorFights(Descent.FLOORS) > Descent.floorFights(1),
            "the bottom asks for no more fights than the first floor")

        -- The third is "not by much", pinned as a number rather than left to a reading. Difficulty
        -- already climbs on every other axis down here -- the stock is grown to Descent.dangerLevel, the
        -- stair carries a general, the company has no hub to go home to -- so a count that doubled would
        -- be charging twice for the same descent.
        assert(Descent.floorFights(Descent.FLOORS) - Descent.floorFights(1) <= 3, string.format(
            "the ramp climbs %d fights over the run, which is no longer 'not by much'",
            Descent.floorFights(Descent.FLOORS) - Descent.floorFights(1)))

        -- ...and the fourth is that it is STEADY, which is the half a span alone cannot say. Three rungs
        -- reached in one jump at the bottom is the same span and a different feature. Every step is one
        -- fight, so the climb is read as the descent asking for more rather than as a wall.
        for f = 2, Descent.FLOORS do
            local step = Descent.floorFights(f) - Descent.floorFights(f - 1)
            assert(step <= 1, string.format(
                "floor %d jumps %d fights over floor %d -- the ramp is a step, not a climb", f, step, f - 1))
        end
    end },

    { name = "a run's whole fight bill stays inside a sitting", fn = function()
        -- THE ONE FIGURE NEITHER CONSTANT STATES, and the reason the flat six was picked in the first
        -- place: there is no hub anywhere in the stack, so a per-floor number is spent Descent.FLOORS
        -- times over and the only honest unit is the RUN. Summed here rather than derived, because the
        -- rounding in Descent.floorFights means the total is not the mean times the count.
        --
        -- The ceiling is what the shape this replaced was measured at (~200 fights a run, `. board-report
        -- 60 descent`) with a wide margin under it. It is not a target -- it is the wall that says a
        -- later retune of either endpoint has quietly rebuilt the thing the budget was cut to fix.
        --
        -- THE BAND MOVED WITH THE STACK, and the old one is worth recording because it was measuring a
        -- different game: 90-140 was cut for a FIFTEEN-floor descent you could bank progress in and walk
        -- across many sittings. The descent resets when you leave it now, so the whole stack has to be
        -- walkable in one run -- eight floors, and about seventy-six fights. The ceiling is what stops a
        -- later retune quietly rebuilding the marathon; the floor is what stops one hollowing the run
        -- out into a corridor.
        local total = 0
        for f = 1, Descent.FLOORS do total = total + Descent.floorFights(f) end
        assert(total >= 60 and total <= 110, string.format(
            "a descent bills %d fights end to end, outside the 60-110 a resettable run is cut to", total))
    end },

    { name = "the deepest floor is still one connected place", fn = function()
        -- A bigger frame is exactly where a carve strands something: the lattice lays one corridor per
        -- `spacing` however big the rectangle is, so a wider board is mostly more of the same warren --
        -- but nothing downstream repairs a break, and a floor in two pieces reads as a small floor with
        -- the stair missing rather than as a bug. Asserted at the deepest board the mode can roll, since
        -- that is the one no measurement was taken against.
        for seed = 1, 6 do
            local grid = floorGrid(seed, { floor = Descent.FLOORS })
            -- Keyed off the cells the flood actually returns rather than off its internal key, so this
            -- keeps working if that encoding ever changes.
            local reached = {}
            for _, c in pairs(grid:reachable()) do reached[c.y * 10000 + c.x] = true end

            local walk, cut = 0, 0
            for y = 1, grid.rows do
                for x = 1, grid.cols do
                    if grid:typeWalkable(grid.cells[y][x].tile) then
                        walk = walk + 1
                        if not reached[y * 10000 + x] then cut = cut + 1 end
                    end
                end
            end
            assert(walk > 0, "seed " .. seed .. ": the deepest floor carved no ground at all")
            assert(cut == 0, string.format(
                "seed %d: %d of %d walkable tiles on the deepest floor are cut off from the entrance",
                seed, cut, walk))

            -- ...and the one tile that must be reachable whatever else is, since it is the way down.
            local stair = grid:objectiveCell()
            assert(stair and reached[stair.y * 10000 + stair.x],
                "seed " .. seed .. ": the deepest floor's stair cannot be walked to from the entrance")
        end
    end },
    -- THE THREE WAYS TO SPEND ON THE PILE all have to actually turn up on a floor, or a relic economy
    -- exists only in the code. The Reliquary and the Merchant have been guaranteed since the descent
    -- landed; the Weeping Stone joins them from the second floor down, because it prices a relic in a
    -- permanent cut to the company's maximum health and a company that has not been hurt yet has nothing
    -- to weigh that against.
    { name = "every floor carries its ways to spend, and the blood-priced one waits for the second",
      fn = function()
        for seed = 1, 12 do
            local first = floorGrid(seed, { floor = 1 })
            assert(countKind(first, "relic_cache") >= 1, "seed " .. seed .. ": floor 1 has no Reliquary")
            assert(countKind(first, "merchant") >= 1, "seed " .. seed .. ": floor 1 has no Merchant")
            assert(countKind(first, "weeping_stone") == 0,
                "seed " .. seed .. ": the Weeping Stone must not stand on the first floor")

            local deeper = floorGrid(seed, { floor = 4 })
            assert(countKind(deeper, "relic_cache") >= 1, "seed " .. seed .. ": floor 4 has no Reliquary")
            assert(countKind(deeper, "merchant") >= 1, "seed " .. seed .. ": floor 4 has no Merchant")
            assert(countKind(deeper, "weeping_stone") >= 1,
                "seed " .. seed .. ": floor 4 has no Weeping Stone")
        end
    end },
}
