-- ON ENVY'S WASTE, NOTHING HERE IS WHAT IT SEEMS (slice G of Envy's bestiary; models/mimic.lua).
--
-- Everywhere else in the rift a fifth of the chests are a Mimic. On Envy's two floors every non-combat
-- stop the waste deals may be the same body wearing that stop's face -- the Cold Forge, the Crossroads,
-- the Dark, the Cold Lectern, the Merchant, the Spinner, the Translation and the Treasure -- at the same
-- fifth, springing on that stop's own act. What this holds:
--
--   * the RATE: every face on an Envy board rolls at Mimic.CHANCE, and every other floor is the chest
--     alone, exactly as it shipped -- asked of the generator AND of the floor descriptor that feeds it;
--   * the SEAM: one table names each face's act and one question (Mimic.springsOn) is asked by every
--     stop -- so no face springs on arrival, and the wiring in states/game.lua is checked by text, since
--     a spec on the model is not a spec on the call sites;
--   * the PAYOUT: a face that is not a chest has swallowed a chest's worth (Spoils.cache at the floor),
--     pinned once, paid guaranteed on top of an elite's roll -- and the cart pays a chest, not its stock;
--   * NO RE-ARM, and a lid still never both wired and alive.
--
-- Pure logic, headless (the two file reads are text, not requires).

local Mimic = require("models.mimic")
local Overworld = require("models.overworld")
local Descent = require("models.descent")
local EncounterBattle = require("models.encounter_battle")
local Player = require("models.player")

local ENVY = Mimic.CIRCLE_KINDS.envy

local function has(list, id)
    for _, v in ipairs(list or {}) do if v == id then return true end end
    return false
end

-- A board whose every stop is `kinds` (a list), so no case is a coin flip on whether a face was laid.
local function board(seed, kinds, opts)
    opts = opts or {}
    local pool = {}
    for _, k in ipairs(kinds) do pool[#pool + 1] = { kind = k, weight = 1 } end
    return Overworld.generate({
        biome = "desert", cols = 13, rows = 13, seed = seed,
        encounterCount = 14, cacheCount = 2, keyCount = 0, ascent = true,
        trapCount = { min = 0, max = 0 },
        guaranteeKinds = {},
        trappedChestChance = opts.trappedChestChance,
        mimicChance = opts.mimicChance,
        mimicKinds = opts.mimicKinds,
        encounters = pool,
    })
end

local function stops(grid)
    local out = {}
    for y = 1, grid.rows do
        for x = 1, grid.cols do
            local e = grid.cells[y][x].encounter
            if e and Mimic.FACES[e.kind] then out[#out + 1] = e end
        end
    end
    return out
end

-- The real floors of a run, by circle, through the descriptor the game builds.
local function floorMaps()
    local player = Player.new()
    local run = Descent.new(player, 4242)
    local out = {}
    for floor = 1, Descent.FLOORS do
        run.floor = floor
        local sin = Descent.sinAt(run, floor)
        out[#out + 1] = { floor = floor, sin = sin and sin.id, map = Descent.floorQuest(run, player).map }
    end
    return out
end

return {
    { name = "the waste names all eight of its stops, and every one of them has an act", fn = function()
        local want = { "anvil", "crossroads", "dark", "lectern", "merchant", "spinner", "translation",
            "treasure" }
        assert(#ENVY == #want, "Envy names " .. #ENVY .. " faces, not eight")
        for _, k in ipairs(want) do
            assert(has(ENVY, k), "Envy's waste does not deal a " .. k .. " mimic")
            assert(Mimic.FACES[k], "the " .. k .. " face has no act to spring on")
        end
        -- Everywhere else, the chest alone.
        assert(#Mimic.kindsOn(nil) == 1 and Mimic.kindsOn(nil)[1] == "treasure", "the Crown deals more than chests")
        assert(#Mimic.kindsOn("pride") == 1 and Mimic.kindsOn("pride")[1] == "treasure",
            "Pride's floors grew faces of their own")
    end },

    { name = "every face on an Envy board rolls alive, and nothing else does", fn = function()
        local all = {}
        for _, k in ipairs(ENVY) do all[#all + 1] = k end
        all[#all + 1] = "rest" -- a non-combat stop that is NOT one of the waste's faces
        local grid = board(777, all, { mimicChance = 100, mimicKinds = ENVY })
        local seen = {}
        for y = 1, grid.rows do
            for x = 1, grid.cols do
                local e = grid.cells[y][x].encounter
                if e and has(ENVY, e.kind) then
                    seen[e.kind] = true
                    assert(e.mimic == true, "a " .. e.kind .. " on the waste at 100% is dead wood")
                elseif e then
                    assert(not e.mimic, "a " .. e.kind .. " stood up, and it wears no face")
                end
            end
        end
        local n = 0
        for _ in pairs(seen) do n = n + 1 end
        assert(n >= 4, "the fixture laid only " .. n .. " kinds of face -- this case proves little")
    end },

    { name = "off the waste only a chest stands up, on the same board", fn = function()
        local all = {}
        for _, k in ipairs(ENVY) do all[#all + 1] = k end
        local grid = board(777, all, { mimicChance = 100 }) -- no mimicKinds: every other circle
        local chests = 0
        for _, e in ipairs(stops(grid)) do
            if e.kind == "treasure" then
                chests = chests + 1
                assert(e.mimic, "a chest at 100% is dead wood")
            else
                assert(not e.mimic, "a " .. e.kind .. " stood up off Envy's waste")
            end
        end
        assert(chests > 0, "the fixture laid no chests")
    end },

    { name = "each face is alive at a fifth, the chest's own rate", fn = function()
        assert(Mimic.CHANCE == 20, "the rate is " .. Mimic.CHANCE .. "%, not a fifth")
        for _, k in ipairs(ENVY) do
            local live, total = 0, 0
            for seed = 1, 12 do
                for _, e in ipairs(stops(board(1000 + seed, { k },
                        { mimicChance = Mimic.CHANCE, mimicKinds = ENVY }))) do
                    total = total + 1
                    if e.mimic then live = live + 1 end
                end
            end
            assert(total >= 60, "too few " .. k .. " stops laid to measure a rate (" .. total .. ")")
            local rate = live / total
            assert(rate > 0.10 and rate < 0.32,
                k .. " is alive at " .. string.format("%.2f", rate) .. ", not about a fifth")
        end
    end },

    { name = "the floors carry the request: Envy names its faces, every other floor the chest", fn = function()
        local envy = 0
        for _, f in ipairs(floorMaps()) do
            assert(f.map.mimicChance == Mimic.CHANCE, "floor " .. f.floor .. " lost its rate")
            local kinds = f.map.mimicKinds
            if f.sin == "envy" then
                envy = envy + 1
                assert(kinds == ENVY, "Envy's floor " .. f.floor .. " does not name the waste's faces")
            elseif f.sin == nil then
                -- The Crown names no list, which the generator reads as the chest alone.
                assert(kinds == nil, "the Crown names faces of its own")
            else
                assert(kinds and #kinds == 1 and kinds[1] == "treasure",
                    "floor " .. f.floor .. " (" .. tostring(f.sin) .. ") names faces beyond the chest")
            end
            -- ...AND THE COPIER HANDS IT OVER, which is what the instruments and the game both read.
            local params = Descent.applyFloorFeatures({}, f.map)
            assert(params.mimicKinds == kinds, "applyFloorFeatures drops mimicKinds")
        end
        assert(envy == Descent.FLOORS_PER_CIRCLE, "Envy holds " .. envy .. " floors of this run")
    end },

    { name = "every face springs on its own act and never on arrival", fn = function()
        local ACTS = { "open", "strike", "buy", "choose", "step", "arrive" }
        for _, k in ipairs(ENVY) do
            local enc = { kind = k, mimic = true }
            assert(Mimic.lurks(enc), "a live " .. k .. " is not lurking")
            local springs = 0
            for _, act in ipairs(ACTS) do
                if Mimic.springsOn(enc, act) then springs = springs + 1 end
            end
            assert(springs == 1, "a " .. k .. " springs on " .. springs .. " acts, not one")
            assert(not Mimic.springsOn(enc, "arrive"), "a " .. k .. " springs on arrival")
            assert(not Mimic.springsOn({ kind = k }, Mimic.FACES[k]), "a dead " .. k .. " sprang")
        end
        assert(Mimic.FACES.treasure == "open", "the chest no longer springs on Open")
        assert(Mimic.FACES.anvil == "strike" and Mimic.FACES.lectern == "strike", "the benches moved off the strike")
        assert(Mimic.FACES.merchant == "buy", "the cart no longer springs on Buy")
        assert(Mimic.FACES.crossroads == "choose", "the signpost no longer springs on a road")
        -- Sprung, it is an elite and wears no face: it cannot spring twice.
        local sprung = Mimic.spring({ kind = "anvil", mimic = true }, { "consumable_healing_potion" })
        assert(not Mimic.lurks(sprung), "a sprung mimic is still lurking")
    end },

    { name = "states/game.lua asks every act, and the bench asks before the rung is taken", fn = function()
        -- THE WIRING, read as text: the table above is honest only while every act it names is asked
        -- somewhere, and the seam only holds while each stop springs through game:springMimic.
        local src = assert(love.filesystem.read("states/game.lua"), "states/game.lua is readable")
        local acts = {}
        for _, act in pairs(Mimic.FACES) do acts[act] = true end
        for act in pairs(acts) do
            assert(src:find('Mimic.springsOn(cell.encounter, "' .. act .. '")', 1, true)
                or src:find('Mimic.springsOn(enc, "' .. act .. '")', 1, true),
                "no stop in states/game.lua springs on '" .. act .. "'")
        end
        assert(src:find("function game:springMimic", 1, true), "the one spring seam is gone")
        local anvil = assert(love.filesystem.read("ui/panels/anvil.lua"), "the bench panel is readable")
        local act, grant = anvil:find("self.onAct(row)", 1, true), anvil:find("Forge.grant(self.player", 1, true)
        assert(act and grant and act < grant, "the bench takes the rung before the mimic can spring")
    end },

    { name = "a face that is not a chest pays a chest's worth, pinned, on top of an elite's roll", fn = function()
        local player = Player.new()
        local enc = { kind = "anvil", mimic = true, tier = 1 }
        local loot = Mimic.chestsWorth(enc, { floorLevel = 4, player = player })
        assert(#loot >= 1, "the bench swallowed nothing")
        assert(enc.loot == loot, "the swallowed chest was not pinned to the stop")
        assert(Mimic.chestsWorth(enc, { floorLevel = 4 }) == loot, "asking twice re-rolled the fight")

        local sprung = Mimic.spring(enc, loot)
        assert(sprung.name == "Mimic", "the sprung bench still calls itself a forge")
        assert(sprung.kind == "elite" and sprung.mimic, "the sprung bench is not the mimic's fight")
        assert(sprung.trophy and sprung.trophy.id == Mimic.TROPHY.id, "the bench offers no Still Hungry")
        local spoils = EncounterBattle.spoils({ encounter = sprung, day = 1, floorLevel = 4 })
        for _, id in ipairs(loot) do
            assert(has(spoils.loot, id), "the win did not hand over " .. id .. " the bench was holding")
        end

        -- A CART PAYS A CHEST, NOT ITS COUNTER (the variant was refused).
        local cart = { kind = "merchant", mimic = true, stock = { { id = "weapon_iron_sword", price = 10 } } }
        local swallowed = Mimic.chestsWorth(cart, { floorLevel = 4 })
        assert(swallowed ~= cart.stock and #swallowed >= 1, "the cart's mimic carries something odd")

        -- ...and with no floor to roll against, the chest blueprint's own floor stands.
        local bare = Mimic.chestsWorth({ kind = "crossroads", mimic = true })
        assert(#bare >= 1, "a face off the floors swallowed nothing at all")

        -- A CHEST'S OWN HAUL IS NEVER RE-ROLLED: the lid hands back what it pinned.
        local chest = { kind = "treasure", mimic = true, loot = { "consumable_healing_potion" } }
        assert(Mimic.chestsWorth(chest, { floorLevel = 4 }) == chest.loot, "a pinned chest re-rolled")
    end },

    { name = "a sprung face does not re-arm, and a wired lid is never alive", fn = function()
        local grid = {
            rows = 1, cols = 3,
            cells = { {
                { encounter = { kind = "elite", id = "encounter_elite" }, cleared = true },
                { encounter = Mimic.spring({ kind = "merchant", mimic = true }, { "consumable_healing_potion" }),
                  cleared = true },
                { encounter = Mimic.spring({ kind = "dark", mimic = true }, { "consumable_healing_potion" }),
                  cleared = true },
            } },
        }
        local woken = Descent.rearmFloor(grid)
        assert(grid.cells[1][1].cleared == nil, "the floor's ordinary elite did not re-arm")
        assert(grid.cells[1][2].cleared and grid.cells[1][3].cleared, "a sprung face woke up again")
        assert(woken == 1, "the count of woken fights includes a mimic")

        local all = {}
        for _, k in ipairs(ENVY) do all[#all + 1] = k end
        local wired = board(31337, all, { mimicChance = 100, trappedChestChance = 100, mimicKinds = ENVY })
        for _, e in ipairs(stops(wired)) do
            assert(not (e.mimic and e.trapped), "a " .. e.kind .. " is both wired and alive")
            if e.kind ~= "treasure" then assert(not e.trapped, "a " .. e.kind .. " was wired") end
        end
    end },
}
