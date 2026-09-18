-- TRAPS ON THE FLOOR, above the arena (models/trap.lua's floor section, Overworld:placeTraps).
--
-- The dungeon lays bad ground between its rewards: cells that bite a company for walking onto them,
-- invisible until somebody is carrying the charm that finds them. What is at risk here is not the
-- arithmetic -- it is three SEAMS that can rot silently:
--
--   * a trap must never be laid on a cell that holds something, or a stop is eaten by one
--   * it must never be laid on a cut, or it stops being bad ground and becomes an unoffered toll
--   * a trap can hurt a company badly and must never be able to finish one, because there is no
--     battle here to lose and no defeat screen to route to
--
-- The detector is the fourth: it is the entire reward for a grid cell, so "carrying the charm reveals
-- them" has to keep being true.

local Trap = require("models.trap")
local Overworld = require("models.overworld")
local Player = require("models.player")
local Character = require("models.character")
local Item = require("models.item")
local Descent = require("models.descent")

-- A floor rolled with traps on it, at a seed a case can pin.
local function floorWith(seed, traps)
    return Overworld.generate({
        biome = "forest", cols = 11, rows = 11, seed = seed,
        encounterCount = 6, cacheCount = 2, keyCount = 0, ascent = true,
        trapCount = traps,
        encounters = { { kind = "combat", weight = 1 } },
    })
end

local function trapCells(grid)
    local out = {}
    for y = 1, grid.rows do
        for x = 1, grid.cols do
            local c = grid.cells[y][x]
            if c.trap then out[#out + 1] = c end
        end
    end
    return out
end

return {
    { name = "traps are laid on empty road, never on a stop and never on the way in", fn = function()
        local grid = floorWith(4242, { min = 5, max = 5 })
        local cells = trapCells(grid)
        assert(#cells > 0, "no traps were laid at all -- the pass is not running")

        for _, c in ipairs(cells) do
            assert(grid:typeWalkable(c.tile), "a trap was laid on ground nobody can walk onto")
            assert(not c.encounter, "a trap was laid on top of a stop, which eats the stop")
            assert(not c.cache, "a trap was laid on a cache")
            assert(not c.gate and not c.key, "a trap was laid on a lock or its key")
            assert(not c.secret, "a trap was laid in a secret, which nobody would ever find")
            assert(not (grid.start and grid.start.x == c.x and grid.start.y == c.y),
                "a trap was laid on the tile the company walks in on")
            -- NOT ON A CUT. A cell that is the only way to somewhere is a toll rather than bad ground,
            -- and an undetected one is a toll nobody was offered a price for.
            assert(#grid:pathNeighbors(c.x, c.y) > 1,
                "a trap was laid on a cut -- the one cell that is the only way through")
        end
    end },

    { name = "a floor lays the count it was asked for, and none when asked for none", fn = function()
        assert(#trapCells(floorWith(77, { min = 0, max = 0 })) == 0,
            "a floor asked for no traps laid some anyway")
        assert(#trapCells(floorWith(77, nil)) == 0,
            "a floor that never mentions traps got some -- every authored quest would grow them")

        local n = #trapCells(floorWith(99, { min = 4, max = 4 }))
        assert(n == 4, "asked for four traps and got " .. n)
    end },

    { name = "every trap a floor can lay is a blueprint that can actually bite", fn = function()
        local ids = Trap.floorable()
        assert(#ids > 0, "nothing is floorable, so no floor can ever lay one")
        for _, id in ipairs(ids) do
            local def = Trap.defs[id]
            assert(def, id .. " is floorable but has no blueprint")
            assert((def.damage or 0) > 0,
                id .. " is floorable with no damage -- out of combat its onTrigger has no board to run "
                .. "against, so it would fire and do nothing")
        end
    end },

    { name = "a trap hurts the whole company and can never finish one", fn = function()
        local player = Player.new()
        player.roster = {
            Character.instantiate("character_knight"),
            Character.instantiate("character_priest"),
        }
        for _, char in ipairs(player.roster) do char.stats.health.current = char.stats.health.max end

        local def = Trap.defs[Trap.floorable()[1]]
        local hurt = Trap.springOn(player, def)
        local n = 0
        for _ in pairs(hurt) do n = n + 1 end
        assert(n >= 1, "the trap fired and nobody felt it")

        -- ...AND IT CANNOT KILL. There is no battle here to lose and no defeat screen to route to, so a
        -- company wiped by a corridor would be a game over arriving with no fight attached to it.
        for _, char in ipairs(player.roster) do char.stats.health.current = 1 end
        Trap.springOn(player, def)
        for _, char in ipairs(player.roster) do
            assert(char.stats.health.current >= 1,
                char.id .. " was killed by a floor trap; one health is the floor")
        end

        -- A body already down is not hit again -- it has nothing left to take and reporting it would
        -- put a name in the toast for damage nobody received.
        player.roster[1].stats.health.current = 0
        local again = Trap.springOn(player, def)
        assert(again[player.roster[1].id] == nil, "a downed body was billed for walking into a trap")
    end },

    { name = "the charm is what finds them, and the best one wins rather than the sum", fn = function()
        local player = Player.new()
        player.roster = { Character.instantiate("character_knight") }
        assert(Trap.detectRadiusFor(player) == 0,
            "a company carrying no charm can see bad ground, which deletes the whole mechanic")

        local charm = Item.instantiate("utility_trap_sense")
        assert(charm, "the fixture charm is gone -- retarget this case")
        Player.addToStash(player, charm)
        local r = Trap.detectRadiusFor(player)
        assert(r == (charm.detectRadius or Trap.DEFAULT_DETECT_RADIUS),
            "the charm in the packs reads as radius " .. r)

        -- BEST, NOT SUM, exactly as Player.visionBonus is: two charms are not twice the warning.
        Player.addToStash(player, Item.instantiate("utility_trap_sense"))
        assert(Trap.detectRadiusFor(player) == r, "two charms stacked into a bigger radius")
    end },

    { name = "the floor's trap count is worth carrying a charm against", fn = function()
        -- A rate nobody meets makes the charm dead weight; a rate that bites every other step makes the
        -- floor a minefield and walking it a chore. Measured against ~91 places on a floor.
        assert(Descent.FLOOR_TRAPS.min >= 1,
            "a floor that can roll zero traps makes the charm a coin flip on whether it does anything")
        assert(Descent.FLOOR_TRAPS.max <= 8,
            "at " .. Descent.FLOOR_TRAPS.max .. " a floor is a minefield rather than a road with bad "
            .. "ground on it")
        assert(Descent.FLOOR_TRAPS.min <= Descent.FLOOR_TRAPS.max, "the trap range is inverted")
    end },
    { name = "some chests are wired, and the mark rides on the lid rather than the ground", fn = function()
        local grid = Overworld.generate({
            biome = "forest", cols = 13, rows = 13, seed = 31337,
            encounterCount = 14, cacheCount = 2, keyCount = 0, ascent = true,
            trapCount = { min = 0, max = 0 },        -- no bad road: this case is only about lids
            trappedChestChance = 100,                -- every chest, so the case is not a coin flip
            encounters = { { kind = "treasure", weight = 1 } },
        })
        local chests, wired = 0, 0
        for y = 1, grid.rows do
            for x = 1, grid.cols do
                local e = grid.cells[y][x].encounter
                if e and e.kind == "treasure" then
                    chests = chests + 1
                    if e.trapped then
                        wired = wired + 1
                        assert(Trap.defs[e.trapped], "a chest is wired to a trap that does not exist")
                    end
                end
            end
        end
        assert(chests > 0, "the fixture laid no chests -- this case proves nothing")
        assert(wired == chests, "at 100% every chest should be wired; " .. wired .. " of " .. chests)

        -- ON THE ENCOUNTER, NOT THE CELL. A wired lid is a property of the thing with the lid; the
        -- cell's own `trap` is bad road, and one tile could honestly carry both.
        for y = 1, grid.rows do
            for x = 1, grid.cols do
                assert(not grid.cells[y][x].trap,
                    "a floor asked for no road traps grew one anyway")
            end
        end
    end },

    { name = "no chest is wired when nobody asked, so an authored quest never grows one", fn = function()
        local grid = Overworld.generate({
            biome = "forest", cols = 11, rows = 11, seed = 5150,
            encounterCount = 10, cacheCount = 1, keyCount = 0, ascent = true,
            encounters = { { kind = "treasure", weight = 1 } },
        })
        for y = 1, grid.rows do
            for x = 1, grid.cols do
                local e = grid.cells[y][x].encounter
                assert(not (e and e.trapped), "a board that never mentioned traps wired a chest")
            end
        end
    end },

    { name = "the wired-chest rate leaves opening one the right default", fn = function()
        -- Below about a fifth the charm is insurance nobody buys and lids stop being thought about;
        -- above a half, opening an unread chest is simply a mistake -- and a reward whose correct play
        -- is to walk past it is not a reward.
        assert(Descent.TRAPPED_CHEST_CHANCE >= 20,
            "at " .. Descent.TRAPPED_CHEST_CHANCE .. "% a wired lid is too rare to be worth a charm")
        assert(Descent.TRAPPED_CHEST_CHANCE <= 50,
            "at " .. Descent.TRAPPED_CHEST_CHANCE .. "% not opening chests becomes the correct play")
    end },
}
