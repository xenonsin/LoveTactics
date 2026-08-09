-- Tests for models/descent.lua -- the run's shape.
--
-- The descent's whole bet is that a SYNTHESIZED floor descriptor is a legal quest: states/game.lua reads
-- a handful of fields off `quest` and never consults Quest.defs, so a table this module builds drives the
-- real overworld/battle stack. These cases pin the two halves of that bet -- that the descriptor is
-- actually accepted by the generator, and that the run it carries survives the real serializer.
--
-- The landing itself (extract-or-descend) lives in states/game.lua and cannot be driven headlessly; what
-- is pinned here is every decision underneath it, which is why they were put in this module rather than
-- in the state.

local Descent = require("models.descent")
local Overworld = require("models.overworld")
local Save = require("models.save")
local Player = require("models.player")
local Biome = require("models.biome")

local function reserialize(data)
    return Save.decode("return " .. Save.encode(data, 0))
end

return {
    { name = "a floor descriptor carries only what states/game.lua reads", fn = function()
        local run = Descent.new(Player.new(), 1234)
        local q = Descent.floorQuest(run)
        assert(type(q.id) == "string" and Descent.isFloorId(q.id), "a floor has a recognisable id")
        assert(type(q.name) == "string" and #q.name > 0, "and a name to put on screen")
        assert(type(q.map) == "table", "and a map block")
        assert(q.map.objective and q.map.objective.meet == true,
            "the stair is a `meet` objective -- the branch that ends a leg without a fight")
        assert(q.descent == run, "the descriptor carries the run states/game.lua keys off")
        assert(type(q.floorLevel) == "number", "and the enemy-level floor for this depth")
    end },

    { name = "a floor's biome is real, and reproduces from the seed", fn = function()
        -- A resume re-derives the board from (seed, floor) alone. If this drifted, Continue would drop
        -- the player onto a different floor than the one they quit.
        local a = Descent.new(Player.new(), 99)
        local b = Descent.new(Player.new(), 99)
        for floor = 1, 9 do
            local x, y = Descent.biomeAt(a, floor), Descent.biomeAt(b, floor)
            assert(x == y, "floor " .. floor .. " reproduces from the same seed")
            assert(Biome.get(x), "floor " .. floor .. " names a biome that exists: " .. tostring(x))
        end
    end },

    { name = "Overworld.generate accepts a synthesized floor", fn = function()
        -- The load-bearing case. If the descriptor is not a legal map spec the whole feature is a
        -- fiction, and it would fail at the first descend rather than here.
        local run = Descent.new(Player.new(), 7)
        local mp = Descent.floorQuest(run).map
        local grid = Overworld.generate({
            biome = mp.biome,
            keyCount = mp.keyCount,
            objective = mp.objective,
            ascent = mp.ascent,
            encounterCount = { min = mp.encounters.min, max = mp.encounters.max },
            encounters = { { kind = "combat", weight = 3 }, { kind = "treasure", weight = 1 } },
            seed = 7,
        })
        assert(grid, "a floor generates a board")
        assert(grid.start, "with somewhere to stand")
        local objective
        for _, row in pairs(grid.cells or {}) do
            for _, cell in pairs(row or {}) do
                if cell.encounter and cell.encounter.kind == "objective" then objective = cell end
            end
        end
        assert(objective, "and a stair to find")
    end },

    { name = "the run survives the real serializer", fn = function()
        -- Save.encode RAISES on a function value, so a closure reaching the run does not degrade -- it
        -- takes the whole save write down. The quest blueprints build `objective.composition` as a
        -- closure, which is exactly the shape that could drift in here later, so this is driven through
        -- the actual encoder rather than a deep-copy.
        local run = Descent.new(Player.new(), 4242)
        Descent.advance(run)
        run.pending[#run.pending + 1] = "quest_bastion_slot_01"
        local back = Descent.restore(reserialize(Descent.snapshot(run)))
        assert(back, "the run round-trips")
        assert(back.floor == run.floor, "at the same depth")
        assert(back.seed == run.seed, "with the same seed, so the board rebuilds identically")
        assert(back.cleared == run.cleared, "and remembers what it had beaten")
        assert(back.pending[1] == "quest_bastion_slot_01", "carrying its unbanked quests")
    end },

    { name = "the rollback point is not serialized twice", fn = function()
        -- The entry snapshot is a whole company. models/save.lua writes it once at the run level and
        -- re-attaches it on restore; if it were also written inside the descent, every save would carry
        -- two full copies of the player and grow by a roster per write.
        local player = Player.new()
        local run = Descent.new(player, 11)
        run.entry = Save.snapshot(player)
        local snap = Descent.snapshot(run)
        assert(snap.entry == nil, "the descent snapshot leaves the rollback point to the run")
    end },

    { name = "a resumed descent gets its rollback point back", fn = function()
        -- The other half of the case above, driven through the real seam. Without the re-attach, the
        -- next floor's game.enter would mint a fresh snapshot and silently bank everything found so far
        -- -- a run that was supposed to be provisional becoming permanent by being quit and resumed.
        local player = Player.new()
        local grid = Overworld.generate({
            cols = 15, rows = 13, seed = 3, biome = "forest",
            encounterCount = 3, keyCount = 0, objective = { name = "The Stair Down", meet = true },
            encounters = { { kind = "combat", weight = 1 } },
        })
        local run = Descent.new(player, 3)
        run.entry = Save.snapshot(player)
        player.activeRun = {
            questId = Descent.floorId(run.floor), prestige = 1, descent = run,
            grid = grid, map = { px = grid.start.x, py = grid.start.y, keysHeld = {}, cacheHaul = {} },
            abilityState = {}, entry = run.entry,
        }
        local restored = Save.restore(reserialize(Save.snapshot(player)))
        assert(restored and restored.resumeRun, "the descent run round-trips through a real save")
        assert(restored.resumeRun.descent, "and comes back as a descent, not a dropped quest")
        assert(restored.resumeRun.descent.entry, "with its rollback point re-attached")
        assert(restored.resumeRun.quest and restored.resumeRun.quest.descent,
            "and a synthesized floor to enter with")
    end },

    { name = "a floor quest is never stored on the run", fn = function()
        -- The rule the case above exists to protect: floorQuest BUILDS a descriptor, the run never holds
        -- one. A descriptor on the run would mean a composition closure one stage from now.
        local run = Descent.new(Player.new(), 5)
        Descent.floorQuest(run)
        local ok = pcall(Save.encode, Descent.snapshot(run), 0)
        assert(ok, "the snapshot encodes -- nothing callable has attached itself to the run")
    end },

    { name = "descending raises the level floor", fn = function()
        local run = Descent.new(Player.new(), 1)
        local shallow = Descent.floorLevel(run)
        for _ = 1, 6 do Descent.advance(run) end
        assert(Descent.depth(run) == 7, "seven floors down")
        assert(Descent.floorLevel(run) > shallow, "and the fights have a higher floor than at the top")
        -- Anchored against the ladder Quest.SLOT_FLOOR used to hand the deepest quest of a line, so the
        -- descent's difficulty lines up with content that was authored against that number.
        assert(Descent.floorLevel(run) == 13, "floor 7 reads 13, the old slot-10 floor")
    end },

    { name = "clearing tracks what was beaten, not where you stand", fn = function()
        -- `floor` is where the party is; `cleared` is what they actually beat. Reading the depth record
        -- off `floor` would credit a player for a floor they walked into and immediately left.
        local run = Descent.new(Player.new(), 3)
        Descent.clearFloor(run)
        Descent.advance(run)
        assert(run.floor == 2, "standing on the second floor")
        assert(run.cleared == 1, "having cleared one")
    end },

    { name = "extraction banks a depth record, and only a record", fn = function()
        local player = Player.new()
        local run = Descent.new(player, 8)
        Descent.clearFloor(run)
        Descent.advance(run)
        Descent.clearFloor(run)
        local out = Descent.extract(player, run)
        assert(out.record, "two floors is a first record")
        assert(player.deepest == 2, "and it is banked on the player")

        -- A shallower second run must not walk the record backwards. This is what makes levels-from-depth
        -- monotonic and unfarmable; without it, repeating floor 1 would pay forever.
        local shallow = Descent.new(player, 9)
        Descent.clearFloor(shallow)
        local again = Descent.extract(player, shallow)
        assert(not again.record, "one floor is not a new record")
        assert(player.deepest == 2, "and the record stands")
    end },
}
