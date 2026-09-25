-- Tests for THE GOLEMS OF GREED (2026-09-25, reviewed over two rounds on "The Golems of Greed" artifact):
-- the Earth Golem, the Gold Golem, their two fights and every piece they drop.
--
--   Shed Plate      an impact blow knocks a plate off: rubble for stone, a coin heap for gold
--   the Vein        a golem's Delve leaves its hole as gold, or one time in three lava -- never a cave-in
--   Regild          a Gold Golem eats a heap: heals, and the gold goes back on as a plate
--   Gold Calls      heaps within 4 slide toward it at its turn's start
--   Chipped Gold    3 gold into the spoils per blow that lands on it
--   the Hoard       four heaps where it falls
--   the drops       Veinfinder, Shale Plating, Heart of Gold, Gilt Plating, and three trophies
-- Each case pins a rule the review approved, on a bare board.

local Character = require("models.character")
local Combat = require("models.combat")
local Descent = require("models.descent")
local Encounter = require("models.encounter")
local Golem = require("models.golem")
local Hazard = require("models.hazard")
local Item = require("models.item")
local Status = require("models.status")
local Wall = require("models.wall")
local AI = require("models.ai")
local Fixture = require("tests.support.fixture")

local unit, openTurn, itemNamed, hp = Fixture.unit, Fixture.openTurn, Fixture.itemNamed, Fixture.hp

local SHELVED = { "ability_veinfinder", "utility_shale_plating", "utility_heart_of_gold", "utility_gilt_plating" }
local TROPHIES = { "utility_lodestone", "utility_spilled_purse", "utility_golden_ballast" }

local function board(n) return Fixture.new(n or 11, n or 11) end

local function units(c, id)
    local out = {}
    for _, u in ipairs(c.units) do if u.char and u.char.id == id then out[#out + 1] = u end end
    return out
end

local function heapAt(c, x, y)
    for _, h in ipairs(Hazard.allAt(c, x, y)) do
        if h.id == "hazard_coin_heap" then return h end
    end
    return nil
end

local function heaps(c)
    local n = 0
    for _, h in ipairs(c.hazards or {}) do if h.alive and h.id == "hazard_coin_heap" then n = n + 1 end end
    return n
end

-- A company body carrying `items`, with health to spare, and nothing else to confuse a case.
local function carrier(x, y, items)
    return unit("character_knight", x, y, { isolate = "bare", items = items or {}, stats = { health = 200 } })
end

-- A blow of WEIGHT (or of `tags`) from `attacker`, dealt straight through the damage path.
local function hit(c, target, attacker, amount, tags)
    return Combat.dealFlatDamage(c, target, amount or 5, tags or { "impact", "physical" }, nil, attacker)
end

-- Pin the vein's roll for one case: 1 strikes lava, anything else strikes gold.
local function withRoll(value, fn)
    local saved = Combat.random
    Combat.random = function() return value end
    local ok, err = pcall(fn)
    Combat.random = saved
    if not ok then error(err, 0) end
end

return {
    -- ------------------------------------------------------------------------------ the content
    {
        name = "the golems are the mountain's constructs, classless, carrying the Delver's Delve as creature kit",
        fn = function()
            for _, id in ipairs({ "character_earth_golem", "character_gold_golem" }) do
                local def = Character.defs[id]
                assert(def.race == "construct" and def.class == nil, id .. " is a construct with no shelf")
                assert(def.resist.impact < 0 and def.resist.slash > 0, id .. " turns an edge and breaks under weight")
                local c = Character.instantiate(id)
                assert(itemNamed(c, "ability_golem_delve"), id .. " delves")
            end
            assert(itemNamed(Character.instantiate("character_earth_golem"), "utility_living_rock"))
            assert(itemNamed(Character.instantiate("character_gold_golem"), "utility_living_gold"))
            local twin, delve = Item.defs["ability_golem_delve"], Item.defs["ability_delve"]
            assert(twin.activeAbility == delve.activeAbility, "it is the Delver's own Delve, not a second one")
            assert(twin.class == "creature" and twin.noSteal and not twin.unstocked, "worn as creature kit")
            local earth, gold = Character.defs["character_earth_golem"], Character.defs["character_gold_golem"]
            assert(gold.stats.health > earth.stats.health and gold.stats.defense > earth.stats.defense
                and gold.stats.damage > earth.stats.damage, "round 2: the Gold Golem is no weaker than the Earth Golem")
            assert(gold.resist.impact <= earth.resist.impact, "...not even in its weakness")
            assert(gold.resist.lightning < 0, "gold conducts")
            assert(gold.boss, "the Gold Golem is a boss body")
        end,
    },
    {
        name = "the drops: four shelved finds and the Gold Golem's three trophies, never sold",
        fn = function()
            for _, id in ipairs(SHELVED) do
                local def = Item.defs[id]
                assert(def and not def.unstocked, id .. " is a find that reaches a shelf")
                assert(def.class ~= "creature", id .. " is a person's piece")
            end
            for _, id in ipairs(TROPHIES) do
                local def = Item.defs[id]
                assert(def and def.unstocked and def.price == nil, id .. " is seen on the rack and never sold")
                assert(def.class ~= "creature", id .. " is a person's piece")
            end
            assert(Item.defs["ability_veinfinder"].class == "mammonite")
            local earth = Character.defs["character_earth_golem"].drops
            assert(earth[1] == "ability_veinfinder" and earth[2] == "utility_shale_plating", "the Earth Golem's two")
            local gold = {}
            for _, id in ipairs(Character.defs["character_gold_golem"].drops) do gold[id] = true end
            for _, id in ipairs({ "utility_heart_of_gold", "utility_gilt_plating", unpack(TROPHIES) }) do
                assert(gold[id], "the Gold Golem drops " .. id)
            end
        end,
    },
    {
        name = "the fights: one golem-only fight on both floors, and the Gold Golem as the approach's spare with a dwarf crew",
        fn = function()
            local workings = Encounter.defs["encounter_greed_the_workings"]
            local elite = Encounter.defs["encounter_greed_the_gold_golem"]
            assert(Encounter.defs["encounter_greed_the_deep_vein"] == nil, "the Deep Vein is cut")
            assert(workings.rung == nil and elite.rung == 1, "the Workings on both floors, the elite on the first")
            assert(elite.kind == "elite" and workings.kind == "combat")
            for _, def in ipairs({ workings, elite }) do
                assert(def.condition({ biome = "cave" }) and not def.condition({ biome = "forest" }), "the cave only")
            end
            for _, body in ipairs(workings.composition({ depth = 5 })) do
                assert(body == "character_earth_golem", "the Workings fields golems and nothing else")
            end
            local n = #workings.composition({ depth = 5 })
            assert(n >= 2 and n <= 3, "the Workings is two or three, got " .. n)
            local seated = elite.composition({ depth = 5 })
            assert(seated[1] == "character_gold_golem" and #seated >= 3, "the Gold Golem and at least two Earth Golems")
            local wave = elite.objective.waves[1]
            assert(elite.objective.type == "killAll" and wave.from == "below", "the crew comes up through the floor")
            for _, b in ipairs(wave.composition()) do assert(b:match("^character_dwarf_"), "and it is dwarves") end
            local greed
            for _, s in ipairs(Descent.SINS) do if s.id == "greed" then greed = s end end
            local spare = false
            for _, e in ipairs(greed.elites.spares) do spare = spare or e == "encounter_greed_the_gold_golem" end
            assert(spare, "the Gold Golem is one of Greed's spares")
        end,
    },
    -- ------------------------------------------------------------------------------ Shed Plate
    {
        name = "Shed Plate: an Earth Golem opens with three plates, and an impact blow knocks one off as rubble",
        fn = function()
            local c = Fixture.combat(board(), carrier(4, 5), { unit("character_earth_golem", 5, 5) })
            local me, golem = c.units[1], units(c, "character_earth_golem")[1]
            assert(Status.stacksOf(golem, "status_stone_plate") == 3, "three plates to begin")
            local def = Combat.flatStat(golem, "defense")
            hit(c, golem, me, 3, { "slash", "physical" })
            assert(Status.stacksOf(golem, "status_stone_plate") == 3, "an edge takes nothing off")
            hit(c, golem, me)
            assert(Status.stacksOf(golem, "status_stone_plate") == 2, "a blow of weight takes a plate")
            assert(Combat.flatStat(golem, "defense") == def - 2, "and 2 Defense with it")
            local rubble = 0
            for _, w in ipairs(c.walls or {}) do
                if w.alive and w.id == "rubble" then
                    rubble = rubble + 1
                    assert(math.abs(w.x - me.x) + math.abs(w.y - me.y) > 1, "the slab falls away from the striker")
                end
            end
            assert(rubble == 1, "the plate is a rubble wall on the floor")
        end,
    },
    {
        name = "the Gold Golem's plates are gold: an impact blow knocks one off as a coin heap",
        fn = function()
            local c = Fixture.combat(board(), carrier(4, 5), { unit("character_gold_golem", 5, 5) })
            local me, golem = c.units[1], units(c, "character_gold_golem")[1]
            assert(Status.stacksOf(golem, "status_gold_plate") == 4, "four plates to begin")
            local before = heaps(c)
            hit(c, golem, me)
            assert(Status.stacksOf(golem, "status_gold_plate") == 3, "one knocked off")
            assert(heaps(c) == before + 1, "and it is a coin heap on the floor")
        end,
    },
    -- ------------------------------------------------------------------------------ the vein
    {
        name = "Strike the Vein: a golem that surfaces leaves its hole as a coin heap, and never a cave-in",
        fn = function()
            withRoll(2, function()
                local c = Fixture.combat(board(), Fixture.walker(9, 9), { unit("character_earth_golem", 2, 8) })
                local golem = units(c, "character_earth_golem")[1]
                Status.apply(c, golem, "status_deeper", { magnitude = 2 })
                openTurn(c, golem)
                assert(Combat.useItem(c, golem, itemNamed(golem.char, "ability_golem_delve"), 5, 6))
                Combat.resolveChannel(c, golem)
                assert(golem.x == 5 and golem.y == 6, "it surfaces where it said it would")
                assert(heapAt(c, 2, 8), "the hole it sank through is gold")
                for _, d in ipairs({ { 0, -1 }, { 1, 0 }, { 0, 1 }, { -1, 0 } }) do
                    assert(c.arena.tiles[6 + d[2]][5 + d[1]].type ~= "lava", "the cave-in stays the Delver's")
                end
            end)
        end,
    },
    {
        name = "one time in three the vein is lava: the hole runs molten instead",
        fn = function()
            withRoll(1, function()
                local c = Fixture.combat(board(), Fixture.walker(9, 9), { unit("character_earth_golem", 2, 8) })
                local golem = units(c, "character_earth_golem")[1]
                openTurn(c, golem)
                assert(Combat.useItem(c, golem, itemNamed(golem.char, "ability_golem_delve"), 5, 6))
                Combat.resolveChannel(c, golem)
                local cell = c.arena.tiles[8][2]
                assert(cell.type == "lava" and not cell.walkable, "the hole is a lava pit")
                assert(not heapAt(c, 2, 8), "and there is no gold in it")
            end)
        end,
    },
    -- ------------------------------------------------------------------------------ the Gold Golem
    {
        name = "Regild: a Gold Golem eats a heap, heals 15%, and the gold goes back on as a plate",
        fn = function()
            local c = Fixture.combat(board(), Fixture.walker(1, 1), { unit("character_gold_golem", 5, 5) })
            local golem = units(c, "character_gold_golem")[1]
            local max = golem.char.stats.health.max
            golem.char.stats.health.current = max - 60
            local before = hp(golem)
            Golem.heap(c, 5, 5) -- a heap under its feet is stepped on at once
            assert(hp(golem) == before + math.ceil(max * Golem.HEAL_SHARE), "it heals")
            assert(Status.stacksOf(golem, "status_gold_plate") == 5, "and wears one more plate than it began with")
            assert(heaps(c) == 0, "the heap is gone")
            assert(Hazard.defs["hazard_coin_heap"].welcomes(golem), "gold is welcome ground to it")
        end,
    },
    {
        name = "Gold Calls to Gold: heaps within 4 slide a tile toward it at its turn's start, and one that arrives is eaten",
        fn = function()
            local c = Fixture.combat(board(), Fixture.walker(1, 1), { unit("character_gold_golem", 5, 5) })
            local golem = units(c, "character_gold_golem")[1]
            Golem.heap(c, 8, 5)
            Golem.heap(c, 6, 6)
            Golem.heap(c, 10, 10) -- out of reach
            Status.onTurnStart(c, golem)
            assert(heapAt(c, 7, 5) and not heapAt(c, 8, 5), "the far heap creeps one tile closer")
            assert(heapAt(c, 10, 10), "a heap beyond 4 stays where it is")
            assert(Status.stacksOf(golem, "status_gold_plate") == 5, "the adjacent heap slid into its mouth")
        end,
    },
    {
        name = "Chipped Gold: a blow that lands pays 3 gold into the spoils",
        fn = function()
            local c = Fixture.combat(board(), carrier(4, 5), { unit("character_gold_golem", 5, 5) })
            local me, golem = c.units[1], units(c, "character_gold_golem")[1]
            local bounty = c.bounty or 0
            hit(c, golem, me, 5, { "slash", "physical" })
            assert((c.bounty or 0) == bounty + 3, "3 gold knocked off it")
        end,
    },
    {
        name = "The Hoard Falls Out: four coin heaps where the Gold Golem falls",
        fn = function()
            local c = Fixture.combat(board(), Fixture.walker(1, 1), { unit("character_gold_golem", 5, 5) })
            local golem = units(c, "character_gold_golem")[1]
            Combat.fell(c, golem)
            assert(heaps(c) == 4, "four heaps, got " .. heaps(c))
            for _, h in ipairs(c.hazards) do
                if h.id == "hazard_coin_heap" then
                    assert(math.max(math.abs(h.x - 5), math.abs(h.y - 5)) == 1, "around where it fell")
                end
            end
        end,
    },
    {
        name = "with nothing to hit, the Gold Golem walks for the gold",
        fn = function()
            local c = Fixture.combat(board(), Fixture.walker(1, 1), { unit("character_gold_golem", 8, 8) })
            local golem = units(c, "character_gold_golem")[1]
            Golem.heap(c, 8, 4)
            local goal = AI.nearestHeap(c, golem)
            assert(goal and goal.x == 8 and goal.y == 4, "the heap is a goal it walks for")
        end,
    },
    -- ------------------------------------------------------------------------------ the drops
    {
        name = "Veinfinder: mines an obstacle into a coin heap, twice a fight, and a preview mines nothing",
        fn = function()
            local c = Fixture.combat(board(), carrier(5, 5, { "ability_veinfinder" }), { unit("character_slime", 10, 10) })
            local me = c.units[1]
            local wall = Wall.place(c, 6, 5, "rubble", { side = "enemy" })
            local vf = itemNamed(me.char, "ability_veinfinder")
            Combat.previewAbility(c, me, vf, 6, 5)
            assert(wall.alive and not heapAt(c, 6, 5), "a hover over the wall leaves it standing")
            openTurn(c, me)
            assert(Combat.useItem(c, me, vf, 6, 5))
            assert(not Wall.at(c, 6, 5), "the rubble is mined away")
            assert(heapAt(c, 6, 5), "and there is gold where it stood")
            c.arena.tiles[4][5].type, c.arena.tiles[4][5].walkable = "rock", false
            vf.cooldownRemaining = 0
            openTurn(c, me)
            assert(Combat.useItem(c, me, vf, 5, 4))
            assert(c.arena.tiles[4][5].walkable and heapAt(c, 5, 4), "solid rock mines open too")
            assert(Status.stacksOf(me, "status_veins_struck") == 2)
            assert(not vf.activeAbility.usable(me), "and that is the fight's two")
        end,
    },
    {
        name = "Shale Plating: three plates, and an impact blow sheds one as rubble behind the wearer",
        fn = function()
            local c = Fixture.combat(board(), carrier(5, 5, { "utility_shale_plating" }), { unit("character_slime", 6, 5) })
            local me, foe = c.units[1], units(c, "character_slime")[1]
            assert(Status.stacksOf(me, "status_shale_plate") == 3)
            hit(c, me, foe)
            assert(Status.stacksOf(me, "status_shale_plate") == 2, "one shed")
            local w
            for _, x in ipairs(c.walls or {}) do if x.alive and x.id == "rubble" then w = x end end
            assert(w and w.x < me.x, "the rubble lands behind the wearer, away from the blow")
        end,
    },
    {
        name = "Heart of Gold: looting a heap heals 15%, once a turn, and a theft or a chip off a golem counts",
        fn = function()
            local c = Fixture.combat(board(), carrier(5, 5, { "utility_heart_of_gold" }), { unit("character_gold_golem", 6, 5) })
            local me, golem = c.units[1], units(c, "character_gold_golem")[1]
            me.char.stats.health.current = 100
            Golem.heap(c, 5, 5)
            assert(hp(me) == 130, "a looted heap heals 15% of 200")
            hit(c, golem, me, 5, { "slash", "physical" })
            assert(hp(me) == 130, "and only once a turn")
            Status.remove(c, me, "status_heart_fed")
            hit(c, golem, me, 5, { "slash", "physical" })
            assert(hp(me) == 160, "gold chipped off a golem is gold taken off a foe")
        end,
    },
    {
        name = "Gilt Plating: a plate knocked off is a heap its wearer can walk back over to wear again",
        fn = function()
            local c = Fixture.combat(board(), carrier(5, 5, { "utility_gilt_plating" }), { unit("character_slime", 6, 5) })
            local me, foe = c.units[1], units(c, "character_slime")[1]
            assert(Status.stacksOf(me, "status_gilt_plate") == 2)
            hit(c, me, foe)
            assert(Status.stacksOf(me, "status_gilt_plate") == 1, "one knocked off")
            local plate
            for _, h in ipairs(c.hazards) do if h.alive and h.plateOf == me then plate = h end end
            assert(plate, "it lies on the floor beside the wearer")
            local bounty = c.bounty or 0
            Combat.teleportUnit(c, me, plate.x, plate.y)
            assert(Status.stacksOf(me, "status_gilt_plate") == 2, "walking back over it puts it on again")
            assert((c.bounty or 0) == bounty, "and the gold is the plate's, not the purse's")
        end,
    },
    {
        name = "Lodestone: at the start of the wearer's turn, a foe within 3 is dragged a tile closer",
        fn = function()
            local c = Fixture.combat(board(), carrier(5, 5, { "utility_lodestone" }),
                { unit("character_slime", 8, 5), unit("character_slime", 10, 10) })
            local me = c.units[1]
            local near, far = unpack(units(c, "character_slime"))
            Status.onTurnStart(c, me)
            assert(near.x == 7 and near.y == 5, "the near foe comes one tile")
            assert(far.x == 10 and far.y == 10, "one beyond 3 does not")
        end,
    },
    {
        name = "Spilled Purse: a foe the wearer kills leaves a coin heap where it fell",
        fn = function()
            -- Not a slime: Greed's slime shrugs off a physical blow, and this one has to land.
            local c = Fixture.combat(board(), carrier(5, 5, { "utility_spilled_purse" }), { Fixture.walker(6, 5) })
            local me, foe = c.units[1], c.units[2]
            foe.char.stats.health.current = 1
            hit(c, foe, me, 50, { "slash", "physical" })
            assert(not foe.alive and heapAt(c, 6, 5), "gold where it fell")
        end,
    },
    {
        name = "Golden Ballast: +6 Defense and unmovable, and each impact blow wears 2 of it off",
        fn = function()
            local plain = Fixture.combat(board(), carrier(5, 5), { unit("character_slime", 6, 5) })
            local base = Combat.flatStat(plain.units[1], "defense")
            local c = Fixture.combat(board(), carrier(5, 5, { "utility_golden_ballast" }), { unit("character_slime", 6, 5) })
            local me, foe = c.units[1], units(c, "character_slime")[1]
            assert(Combat.flatStat(me, "defense") == base + 6, "+6 Defense")
            assert(Status.blocksForcedMove(me), "nothing moves the wearer")
            hit(c, me, foe)
            assert(Combat.flatStat(me, "defense") == base + 4, "a blow of weight wears 2 off")
        end,
    },
}
