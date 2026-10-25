-- Not last run's fights (models/descent.lua: Descent.noteMet, Descent.closeRunFights, Descent.skipLastRun).
--
-- The rift resets every run and a floor keeps its identity by depth, so its pool is the same pool every
-- run. A run writes down what it met on each floor; the run's end hands that to the player; the next
-- run's pool leaves those fights out wherever the floor has others to deal, and deals them anyway where
-- it does not. The billed elite, the adventuring parties and everything seated outside the pool are
-- never skipped.

local Descent = require("models.descent")
local Player = require("models.player")
local Save = require("models.save")

local function has(list, id)
    for _, e in ipairs(list) do if e.id == id then return true end end
    return false
end

local function floorSix()
    local danger = Descent.dangerLevel({ floor = 6 })
    return Descent.floorPool({ depth = 6, rung = 2, biome = "cave",
        quest = { sin = "greed", floorLevel = danger, dangerLevel = danger } })
end

local function readText(path)
    local f = assert(io.open(path, "rb"), "cannot read " .. path)
    local s = f:read("*a")
    f:close()
    return s
end

return {
    {
        name = "a run writes down the fights it met, per floor, once each",
        fn = function()
            local run = { floor = 3 }
            Descent.noteMet(run, { kind = "combat", id = "encounter_a" })
            Descent.noteMet(run, { kind = "combat", id = "encounter_a" })
            Descent.noteMet(run, { kind = "elite", id = "encounter_b" })
            Descent.noteMet(run, { kind = "objective", id = "the_stair" })
            Descent.noteMet(run, { kind = "rest", id = "encounter_rest" })
            local met = run.met and run.met["3"]
            assert(met and #met == 2, "two fights met on floor three, got " .. tostring(met and #met))
            assert(met[1] == "encounter_a" and met[2] == "encounter_b", "in the order they were met")
            run.floor = 4
            Descent.noteMet(run, { kind = "combat", id = "encounter_c" })
            assert(run.met["4"][1] == "encounter_c", "floor four keeps its own list")
        end,
    },
    {
        name = "the run's end makes it last run, replacing the run before",
        fn = function()
            local p = { lastRunFights = { ["9"] = { "encounter_old" } } }
            local run = { floor = 2, met = { ["2"] = { "encounter_x" } } }
            Descent.closeRunFights(p, run)
            assert(p.lastRunFights["2"][1] == "encounter_x", "this run's fights are now last run's")
            assert(p.lastRunFights["9"] == nil, "only one run is remembered")
            run.met["2"][2] = "encounter_y"
            assert(p.lastRunFights["2"][2] == nil, "copied, not aliased to the run")
            Descent.closeRunFights(p, { floor = 1 })
            assert(p.lastRunFights == nil, "a run that met nothing leaves nothing to skip")
        end,
    },
    {
        name = "a fight met last run is not dealt again when the floor has another",
        fn = function()
            local pool = floorSix()
            local natives = {}
            for _, e in ipairs(pool) do
                if e.kind == "combat" and not (require("models.encounter").get(e.id) or {}).party then
                    natives[#natives + 1] = e.id
                end
            end
            assert(#natives >= 2, "floor six deals at least two ordinary fights, got " .. #natives)
            local gone = natives[1]
            local p = { lastRunFights = { ["6"] = { gone } } }
            local out = Descent.skipLastRun(pool, p, 6)
            assert(not has(out, gone), gone .. " was met last run and is still in the pool")
            assert(#out == #pool - 1, "only the one fight left the pool")
            assert(has(pool, gone), "the floor's own pool is untouched")
            -- ...and the walk never rolls it: the wandering pick draws from the filtered pool.
            for leg = 1, 200 do
                local rolled = Descent.wander({ seed = 4242, leg = leg }, out)
                assert(rolled and rolled.id ~= gone, "the prowl dealt last run's fight on leg " .. leg)
            end
            -- Another floor's record is not this floor's.
            assert(#Descent.skipLastRun(pool, { lastRunFights = { ["5"] = { gone } } }, 6) == #pool,
                "floor five's record skipped a fight on floor six")
        end,
    },
    {
        name = "a fight met last run is dealt anyway when the pool would be empty without it",
        fn = function()
            local pool = {
                { id = "encounter_only_a", kind = "combat", weight = 1 },
                { id = "encounter_only_b", kind = "combat", weight = 1 },
                { id = "encounter_rest", kind = "rest", weight = 1 },
            }
            local p = { lastRunFights = { ["1"] = { "encounter_only_a", "encounter_only_b", "encounter_rest" } } }
            local out = Descent.skipLastRun(pool, p, 1)
            assert(#out == 3, "every fight was met last run, so the floor deals them again")
            assert(Descent.wander({ seed = 1, leg = 1 }, out), "and the prowl still finds one")
        end,
    },
    {
        name = "the billed elite is never skipped; the spares are",
        fn = function()
            local pool = {
                { id = "encounter_e1", kind = "elite", weight = 1, billed = true },
                { id = "encounter_e2", kind = "elite", weight = 1 },
                { id = "encounter_e3", kind = "elite", weight = 1 },
                { id = "encounter_c1", kind = "combat", weight = 1 },
            }
            local p = { lastRunFights = { ["2"] = { "encounter_e1", "encounter_e2" } } }
            local out = Descent.skipLastRun(pool, p, 2)
            assert(has(out, "encounter_e1"), "the floor's billed elite left the floor")
            assert(not has(out, "encounter_e2"), "a spare met last run was dealt again")
            assert(has(out, "encounter_e3") and has(out, "encounter_c1"), "the rest stay")
            -- The real pool marks its billing: Greed's seat on its second floor.
            local greed
            for _, s in ipairs(Descent.SINS) do if s.id == "greed" then greed = s end end
            local billed = 0
            for _, e in ipairs(floorSix()) do
                if e.billed then
                    billed = billed + 1
                    assert(e.kind == "elite" and e.id == greed.elites.seat, "billed " .. tostring(e.id))
                end
            end
            assert(billed == 1, "floor six bills exactly one elite, got " .. billed)
        end,
    },
    {
        name = "what was met rides the run save, and last run rides the profile",
        fn = function()
            local snap = Descent.snapshot({ floor = 3, seed = 1, met = { ["3"] = { "encounter_a" } } })
            local back = Descent.restore(snap)
            assert(back.met and back.met["3"][1] == "encounter_a", "a resumed run forgot what it met")
            assert(Descent.restore(Descent.snapshot({ floor = 1, seed = 1 })).met == nil, "nothing met reads as nil")

            local p = Player.new()
            p.lastRunFights = { ["4"] = { "encounter_b" } }
            local restored = Save.restore(Save.snapshot(p))
            assert(restored.lastRunFights and restored.lastRunFights["4"][1] == "encounter_b",
                "last run's fights did not survive a save")
        end,
    },
    {
        name = "the overworld deals from the filtered pool, notes every fight, and closes every exit",
        fn = function()
            -- A SOURCE SCAN of the wiring, because the model above can be right with nobody calling it.
            local src = readText("states/game.lua")
            assert(src:find("Descent.skipLastRun(Descent.floorPool(ctx)", 1, true),
                "game.floorPool is not filtered through Descent.skipLastRun")
            assert(src:find("Descent.noteMet(game.descent, cell.encounter)", 1, true),
                "a fight stepped onto is not noted")
            local n = 0
            for _ in src:gmatch("Descent%.closeRunFights%(") do n = n + 1 end
            assert(n >= 5, "every run end (catch-all, wipe, climb-out, the Crown twice) promotes; got " .. n)
        end,
    },
}
