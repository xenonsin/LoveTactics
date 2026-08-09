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
        -- The stair opened as a `meet` while floors were procedural skeletons; from stage 3 it is a
        -- guardian, which is a plain combat objective and takes states/game.lua's fought-objective
        -- branch. What matters to THIS case is only that the descriptor carries one at all.
        assert(q.map.objective and q.map.objective.composition,
            "the stair is an objective with something standing on it")
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

    { name = "the circles agree with the vendor blueprints that define them", fn = function()
        -- Descent.SINS says which vendor is which circle, and data/vendors/*.lua says which sin a
        -- vendor faces. Two statements of one fact, so this asserts they are the same fact rather
        -- than restating either -- a sin renamed in data fails here instead of silently leaving a
        -- floor paying into a house it no longer faces.
        local Vendor = require("models.vendor")
        local seenSin, seenVendor = {}, {}
        for _, sin in ipairs(Descent.SINS) do
            local def = Vendor.get(sin.vendor)
            assert(def, sin.id .. " names vendor '" .. tostring(sin.vendor) .. "', which does not exist")
            assert(def.sin == sin.id, sin.vendor .. " faces " .. tostring(def.sin) ..
                " in data, but Descent.SINS pairs it with " .. sin.id)
            assert(not seenSin[sin.id], "two circles claim the sin " .. sin.id)
            assert(not seenVendor[sin.vendor], "two circles claim the vendor " .. sin.vendor)
            seenSin[sin.id], seenVendor[sin.vendor] = true, true
        end
        -- Every vendor that faces a sin must BE a circle. The Cafe sells suppers and faces nothing,
        -- so it is not counted -- but a new house added to the game with a sin and no floor would be
        -- a circle nobody can reach, which is exactly the silence worth failing on.
        for id, def in pairs(Vendor.defs) do
            if def.sin then
                assert(seenVendor[id], "vendor '" .. id .. "' faces " .. def.sin ..
                    " but no floor is that circle")
            end
        end
    end },

    { name = "a floor's ground and guardian are real content", fn = function()
        -- Every biome resolves and every guardian body is a blueprint the arena can actually spawn.
        -- Cheap, and it is the whole failure mode of a table of ids: a typo here is a floor that
        -- generates fine and then cannot open its own stair.
        local Character = require("models.character")
        for _, sin in ipairs(Descent.SINS) do
            assert(Biome.get(sin.biome), sin.id .. " is fought on '" .. tostring(sin.biome) ..
                "', which is not a biome")
            for _, key in ipairs({ "lead", "filler" }) do
                local id = sin.guardian[key]
                assert(Character.defs[id], sin.id .. "'s guardian " .. key .. " '" .. tostring(id) ..
                    "' is not a character blueprint")
            end
        end
    end },

    { name = "the first seven floors are the seven circles, in some order", fn = function()
        -- A SHUFFLE, not a per-floor pick. The distinction is the feature: a pick lets a run draw
        -- Wrath three times and never reach Envy, and the first seven floors stop being a tour of the
        -- circles. Checked across many seeds because a single one could be a lucky permutation.
        for seed = 1, 40 do
            local run = Descent.new(nil, seed)
            local seen = {}
            for floor = 1, #Descent.SINS do
                local sin = Descent.sinAt(run, floor)
                assert(not seen[sin.id], "seed " .. seed .. " deals " .. sin.id .. " twice in one cycle")
                seen[sin.id] = true
            end
        end
    end },

    { name = "past the seventh the deck is dealt again, differently", fn = function()
        -- The endless half, which falls out of the cycle arithmetic rather than needing its own rule.
        -- Both halves are asserted: the second cycle is a full deck again, and it is not simply the
        -- first one replayed -- otherwise floor 8 would be floor 1 with bigger numbers.
        local run = Descent.new(nil, 4242)
        local n = #Descent.SINS
        local seen, sameSeat = {}, 0
        for floor = n + 1, n * 2 do
            local sin = Descent.sinAt(run, floor)
            assert(not seen[sin.id], "the second cycle deals " .. sin.id .. " twice")
            seen[sin.id] = true
            if sin.id == Descent.sinAt(run, floor - n).id then sameSeat = sameSeat + 1 end
        end
        assert(sameSeat < n, "the second cycle repeated the first exactly -- the salt is not reaching the deal")
    end },

    { name = "a run lays out the same circles from the same seed, forever", fn = function()
        -- The determinism the resume rests on: a run is saved as a seed and a depth, and everything
        -- else is re-derived. Two runs on one seed must agree, and a run must still agree with itself
        -- after a round trip through the serializer.
        local a, b = Descent.new(nil, 777), Descent.new(nil, 777)
        for floor = 1, 20 do
            assert(Descent.sinAt(a, floor).id == Descent.sinAt(b, floor).id,
                "two runs on seed 777 disagree about floor " .. floor)
        end
        local restored = Descent.restore(reserialize(Descent.snapshot(a)))
        for floor = 1, 20 do
            assert(Descent.sinAt(restored, floor).id == Descent.sinAt(a, floor).id,
                "a resumed run disagrees about floor " .. floor)
        end
    end },

    { name = "a floor is mostly fights, and its elites do not grow with the company", fn = function()
        -- The pacing claim, checked on the pool rather than on a generated board so it is a statement
        -- about the RULE and not about one lucky seed. Measured on real boards the transform takes a
        -- twelve-stop floor from 5.2 fights (2.8 of them elites) to 7.4 (2.0) -- many short fights
        -- instead of few long ones, which is the whole point of the skirmish tier.
        local function shares(prestige)
            local combat, elite, texture = 0, 0, 0
            for _, e in ipairs(Descent.floorPool({ biome = "swamp", prestige = prestige })) do
                if e.kind == "combat" then combat = combat + e.weight
                elseif e.kind == "elite" then elite = elite + e.weight
                else texture = texture + e.weight end
            end
            return combat, elite, texture
        end

        local combat, elite, texture = shares(6)
        assert(combat > texture * 3, "a floor's free draws must be fights, not towns -- every stop " ..
            "spent on texture is a skirmish the floor does not have")
        assert(elite < combat / 2, "an elite is punctuation, not the sentence")

        -- The runaway this pins shut: `weight = prestige` on the elite blueprint is a campaign dial,
        -- and on a descent it would crowd ordinary fights out without limit as the company grows --
        -- so by prestige 20 an "ordinary road stop" would be a set-piece again.
        --
        -- Asserted PER BLUEPRINT rather than on the family total, because the total legitimately moves
        -- with prestige for a different reason: `minPrestige` gates whole blueprints in as the company
        -- grows, and an elite that is not eligible at prestige 1 contributes nothing. That is
        -- eligibility, which is the pool's business and correct; what must not move is the weight.
        for _, prestige in ipairs({ 1, 6, 30 }) do
            for _, e in ipairs(Descent.floorPool({ biome = "swamp", prestige = prestige })) do
                if e.kind == "elite" then
                    assert(e.weight == Descent.ELITE_WEIGHT, e.id .. " weighs " .. e.weight ..
                        " at prestige " .. prestige .. " -- an elite's weight is pinned flat")
                end
            end
        end
    end },

    { name = "a floor names its house, pins its board, and stands something on the stair", fn = function()
        -- The four things stage 3 added to the descriptor, checked together because they are one
        -- statement: this floor is a circle. The board size especially -- left to deriveDims, twelve
        -- stops reaches the generator's 27x19 cap, which is the marathon warren its own header warns
        -- against.
        local run = Descent.new(nil, 31337)
        local sin = Descent.sinAt(run, 1)
        local quest = Descent.floorQuest(run)
        assert(quest.sponsor == sin.vendor, "the floor must name its house, or nothing tags its materials")
        assert(quest.sin == sin.id, "and say which circle it is")
        assert(quest.map.biome == sin.biome, "and be fought on that circle's ground")
        assert(quest.map.cols == Descent.FLOOR_COLS and quest.map.rows == Descent.FLOOR_ROWS,
            "the board is pinned, never derived")
        assert(quest.map.cacheCount, "the cache count is pinned too -- derived, it triples with density")

        local obj = quest.map.objective
        assert(not obj.meet, "the stair is fought now, not walked onto")
        assert(obj.win and obj.win.type == "killAll", "and it is won by clearing it")
        local bodies = obj.composition({})
        assert(bodies[1] == sin.guardian.lead, "the guardian leads with its own house's body")
        assert(#bodies >= 3, "a guardian is a set-piece, not a skirmish")

        -- Deeper stairs are held harder. Read off the floor rather than off prestige, so this is a
        -- statement about how far down the party went.
        local deep = Descent.new(nil, 31337)
        deep.floor = 7
        local deepBodies = Descent.floorQuest(deep).map.objective.composition({})
        assert(#deepBodies > #bodies, "floor 7's stair must be held harder than floor 1's")
    end },
}
