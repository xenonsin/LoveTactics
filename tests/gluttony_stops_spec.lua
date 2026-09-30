-- GLUTTONY'S OWN STOPS (reviewed in three rounds, 2026-09-29: "I don't want fights, just encounters"): the
-- Carcass, the Watering Hole and the Maw, and the one seam two of them needed -- a status queued for the next
-- fight on this floor (Descent.queueOpening).
--
-- What is held here is every rule a review line approved, through the real models: which floors seat which
-- stop, what each choice reaches for, what the Maw takes and gives back, and that all of it rides a save.
-- The panel and the state branch are not reachable headless (states/ requires love.graphics); the verbs they
-- bind are held by tests/crossroads_spec.lua's BOUND list, which scans states/game.lua for them.

local Character = require("models.character")
local Crossroads = require("models.crossroads")
local Descent = require("models.descent")
local Encounter = require("models.encounter")
local Identify = require("models.identify")
local Item = require("models.item")
local Maw = require("models.maw")
local Overworld = require("models.overworld")
local Player = require("models.player")

local function sinNamed(id)
    for _, sin in ipairs(Descent.SINS) do if sin.id == id then return sin end end
end

-- The floor number of Gluttony's approach (rung 1) and seat (rung 2) on a first descent.
local function gluttonyFloors()
    local run = Descent.new(Player.new(), 1)
    local out = {}
    for floor = 1, Descent.FLOORS do
        run.floor = floor
        if Descent.sinAt(run, floor) and Descent.sinAt(run, floor).id == "gluttony" then
            out[Descent.floorWithinCircle(floor)] = floor
        end
    end
    return out
end

-- A ctx that records what a stop's resolve reached for (tests/crossroads_spec.lua's shape).
local function recorder()
    local log = { sealed = 0, refill = {}, restored = 0, injured = 0, revealed = 0, queued = {}, notes = {} }
    return log, {
        rnd = function() return 0 end,
        notify = function(m) log.notes[#log.notes + 1] = m end,
        grantSealed = function() log.sealed = log.sealed + 1; return true end,
        refill = function(share, stats) log.refill[#log.refill + 1] = { share = share, stats = stats } end,
        restore = function() log.restored = log.restored + 1 end,
        injure = function() log.injured = log.injured + 1; return "someone" end,
        revealElites = function() log.revealed = log.revealed + 1; return 2 end,
        queueOpening = function(side, id, n) log.queued[#log.queued + 1] = { side = side, id = id, n = n } end,
    }
end

local function option(stop, label)
    for _, o in ipairs(Crossroads.STOPS[stop].options) do if o.label == label then return o end end
    error(stop .. " has no option " .. label)
end

-- A sealable blueprint id at exactly `rung`, not a consumable, for feeding.
local function pieceAt(rung)
    local ids = {}
    for id, def in pairs(Item.defs) do
        if (def.unlockLevel or 0) == rung and def.type ~= "consumable" and not def.bound
            and Identify.canSeal(def) then ids[#ids + 1] = id end
    end
    table.sort(ids)
    return ids[1]
end

return {
    { name = "the three stops have blueprints, never roll, and each has a gloss and a mark kind", fn = function()
        for _, kind in ipairs({ "carcass", "watering_hole", "maw" }) do
            local found
            for id, def in pairs(Encounter.defs) do if def.kind == kind then found = def end end
            assert(found, kind .. " has no blueprint")
            assert((found.weight or 0) == 0, kind .. " would roll onto a board at random")
            assert(Encounter.GLOSS[kind], kind .. " has no gloss sentence")
        end
    end },

    { name = "Gluttony's approach seats all three, its seat seats two, and no other circle seats them", fn = function()
        local sin = sinNamed("gluttony")
        local floors = gluttonyFloors()
        assert(floors[1] and floors[2], "Gluttony's two floors were found")
        local k1, g1 = Descent.circleStops(sin, floors[1])
        assert(table.concat(k1, ",") == "carcass,watering_hole,maw", "approach: " .. table.concat(k1, ","))
        assert(g1.maw.deadEnd and g1.maw.count == 1, "the Maw asks for one dead end")
        local k2 = Descent.circleStops(sin, floors[2])
        assert(table.concat(k2, ",") == "carcass,watering_hole", "seat: " .. table.concat(k2, ","))
        local mine = { carcass = true, watering_hole = true, maw = true }
        for _, other in ipairs(Descent.SINS) do
            if other.id ~= "gluttony" then
                for floor = 1, Descent.FLOORS do
                    for _, k in ipairs((Descent.circleStops(other, floor))) do
                        assert(not mine[k], other.id .. " seats Gluttony's " .. k)
                    end
                end
            end
        end
    end },

    { name = "a generated Gluttony approach actually stands one of each on the board", fn = function()
        local floors = gluttonyFloors()
        local run = Descent.new(Player.new(), 909)
        run.floor = floors[1]
        local mp = Descent.floorQuest(run, Player.new()).map
        local grid = Overworld.generate({
            biome = mp.biome, cols = mp.cols, rows = mp.rows, seed = 4242, ascent = true, keyCount = 0,
            encounterCount = mp.encounters, cacheCount = mp.cacheCount,
            encounters = { { kind = "combat", weight = 3 }, { kind = "treasure", weight = 1 } },
            secrets = mp.secrets, exitAtStart = mp.exitAtStart,
            guaranteeKinds = mp.guaranteeKinds, guarantee = mp.guarantee,
        })
        local n = {}
        for y = 1, grid.rows do
            for x = 1, grid.cols do
                local e = grid.cells[y][x].encounter
                if e then n[e.kind] = (n[e.kind] or 0) + 1 end
            end
        end
        for _, kind in ipairs({ "carcass", "watering_hole", "maw" }) do
            assert(n[kind] == 1, string.format("%s stands %d times on the approach, not once", kind, n[kind] or 0))
        end
    end },

    { name = "the Carcass: pick it over, eat, or leave -- and what each reaches for", fn = function()
        local log, ctx = recorder()
        option("carcass", "Pick it over").resolve(ctx)
        assert(log.sealed == 1, "picking it over hands up a sealed find")
        assert(log.queued[1] and log.queued[1].side == "enemy" and log.queued[1].id == "status_starving"
            and log.queued[1].n == 1, "and the beasts in the next fight open Starving 1")

        log, ctx = recorder()
        option("carcass", "Eat").resolve(ctx)
        assert(log.refill[1] and log.refill[1].share == 0.25 and log.refill[1].stats[1] == "health"
            and #log.refill[1].stats == 1, "eating heals a quarter of health, and only health")
        assert(log.queued[1] and log.queued[1].side == "party" and log.queued[1].id == "status_full"
            and log.queued[1].n == 1, "and the company opens its next fight Full 1")

        log, ctx = recorder()
        option("carcass", "Leave it").resolve(ctx)
        assert(log.sealed == 0 and #log.refill == 0 and #log.queued == 0, "leaving it does nothing")
    end },

    { name = "the Watering Hole: drink first, wait your turn, or watch the order", fn = function()
        local log, ctx = recorder()
        option("watering_hole", "Drink first").resolve(ctx)
        assert(log.restored == 1 and log.injured == 1, "drinking first restores everything and injures one")
        log, ctx = recorder()
        option("watering_hole", "Wait your turn").resolve(ctx)
        assert(log.refill[1] and log.refill[1].share == 0.5 and log.refill[1].stats == nil,
            "waiting gives back half of every pool")
        assert(log.restored == 0 and log.injured == 0, "and costs nothing")
        log, ctx = recorder()
        option("watering_hole", "Watch the order").resolve(ctx)
        assert(log.revealed == 1 and #log.refill == 0, "watching reveals the elites and drinks nothing")
    end },

    { name = "Player.refill gives back a flat share of each maximum, never past it", fn = function()
        local p = Player.new()
        local c = p.roster[1]
        local hp, mp = c.stats.health, c.stats.mana
        hp.current = 1
        if type(mp) == "table" then mp.current = 0 end
        Player.refill(p, 0.25, { "health" })
        assert(hp.current == math.min(hp.max, 1 + math.ceil(hp.max * 0.25)), "a quarter of max, flat")
        if type(mp) == "table" and mp.max > 0 then assert(mp.current == 0, "health only when told so") end
        Player.refill(p, 5)
        assert(hp.current == hp.max, "never past the maximum")
    end },

    { name = "the next fight on this floor: queued, merged, spent once, and lost on the stair", fn = function()
        local run = Descent.new(Player.new(), 1)
        run.floor = 3
        Descent.queueOpening(run, "party", "status_full", 1)
        Descent.queueOpening(run, "party", "status_full", 1)
        Descent.queueOpening(run, "enemy", "status_starving", 1)
        local rows = Descent.takeOpening(run)
        assert(#rows == 2, "one row per side and status")
        assert(rows[1].side == "party" and rows[1].id == "status_full" and rows[1].opts.magnitude == 2,
            "the same stop twice adds to the row")
        assert(#Descent.takeOpening(run) == 0, "and one fight spends it")

        Descent.queueOpening(run, "party", "status_full", 1)
        run.floor = 4
        assert(#Descent.takeOpening(run) == 0, "a company that walked down the stair carries nothing")
    end },

    { name = "the queue rides a save", fn = function()
        local run = Descent.new(Player.new(), 1)
        run.floor = 2
        Descent.queueOpening(run, "enemy", "status_starving", 1)
        local back = Descent.restore(Descent.snapshot(run))
        local rows = Descent.takeOpening(back)
        assert(#rows == 1 and rows[1].id == "status_starving" and rows[1].side == "enemy",
            "a Carcass picked over, saved and resumed still has the beasts opening Starving")
    end },

    { name = "the Maw: the price climbs one a feeding, forever", fn = function()
        local p = Player.new()
        assert(Maw.price(p) == 1, "the first feeding costs one piece")
        Maw.state(p).fed = 3
        assert(Maw.price(p) == 4, "the fourth costs four")
    end },

    { name = "the Maw eats pieces, not supplies or husks", fn = function()
        local id = pieceAt(1)
        assert(id, "a sealable piece at rank 1 exists")
        assert(Maw.feedable(Item.instantiate(id)), "a read piece of gear is food")
        for cid, def in pairs(Item.defs) do
            if def.type == "consumable" then
                assert(not Maw.feedable(Item.instantiate(cid)), "a consumable is a supply, not a piece")
                break
            end
        end
        local husk = Identify.sealed(id, 1)
        assert(husk and not Maw.feedable(husk), "an unread husk cannot be fed")
    end },

    { name = "the Maw destroys what it is fed and hands back one sealed find a rank above the best", fn = function()
        local low, high = pieceAt(1), pieceAt(3)
        assert(low and high, "pieces at ranks 1 and 3 exist")
        local p = Player.new()
        p.descentRun = { entry = {} } -- underground: the find is stowed in the pack
        p.pack = { Item.instantiate(low), Item.instantiate(high) }
        Maw.state(p).fed = 1 -- so it wants two

        local refused = Maw.feed(p, { 1 }, 2)
        assert(refused == nil and #p.pack == 2, "one piece when it wants two is refused, and nothing is taken")

        local find = Maw.feed(p, { 1, 2 }, 2, function() return 0 end)
        assert(find and find.id, "fed two, it gives something back")
        assert(Item.defs[find.id].unlockLevel == 4, "a rank above the best fed (3): got "
            .. tostring(Item.defs[find.id].unlockLevel))
        assert(#p.pack == 1 and p.pack[1].id == find.id and Identify.isUnidentified(p.pack[1]),
            "both pieces are gone, and the find is in the pack, sealed")
        assert(Maw.price(p) == 3, "and next time it wants three")
    end },

    { name = "the Maw's count rides the save", fn = function()
        local Save = require("models.save")
        local p = Player.new()
        Maw.state(p).fed = 2
        local back = Save.restore(Save.snapshot(p))
        assert(back.gluttonyMaw and back.gluttonyMaw.fed == 2, "a reload keeps the price where it climbed to")
    end },
}
