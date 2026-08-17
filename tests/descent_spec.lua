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

    { name = "descending raises the level floor, and the ceiling did not move with the floor count", fn = function()
        local run = Descent.new(Player.new(), 1)
        local shallow = Descent.floorLevel(run)
        for _ = 1, 6 do Descent.advance(run) end
        assert(Descent.depth(run) == 7, "seven floors down")
        assert(Descent.floorLevel(run) > shallow, "and the fights have a higher floor than at the top")

        -- THE ANCHOR IS THE BOTTOM, NOT A FLOOR NUMBER, and that is the whole point of this case. A
        -- circle owns a stratum now (Descent.FLOORS_PER_CIRCLE), so the descent went from eight floors
        -- to fifteen -- and at the old two levels per floor the same slope would have reached 29 and
        -- walked off the end of every growth curve and shelf tier in the game. The ladder got longer and
        -- the ceiling stayed put. Asserted as a bound rather than an equality so a third floor per
        -- circle does not have to come and edit a number here.
        local deepest = Descent.new(Player.new(), 1)
        deepest.floor = Descent.FLOORS
        assert(Descent.floorLevel(deepest) <= 16,
            "the bottom reads " .. Descent.floorLevel(deepest) ..
            ", past what the growth tables and the shelf were built for")

        -- The seventh circle's general, who is the deepest authored fight the campaign ever handed out
        -- at level 13 (Quest.SLOT_FLOOR's old deepest rung). She should land within a point of it.
        local lastGeneral = Descent.new(Player.new(), 1)
        lastGeneral.floor = Descent.CIRCLE_FLOORS
        assert(Descent.isGeneralFloor(lastGeneral.floor), "the last circle floor is a general's")
        local lvl = Descent.floorLevel(lastGeneral)
        assert(lvl >= 12 and lvl <= 15,
            "the last general reads " .. lvl .. ", off the ladder her fight was authored against")
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

    { name = "extraction accounts for the run and banks nothing", fn = function()
        -- THE MODE, PINNED. The descent is a separate game from the campaign now: a run raises its own
        -- company on its own floors and nothing it does reaches a save. Extraction used to write a depth
        -- record, per-house standing and a prestige point per floor onto the player; this asserts that
        -- it no longer touches the player at all, which is the whole difference between a game mode and
        -- a progression engine.
        local player = Player.new()
        local prestige, deepest = player.prestige, player.deepest

        local run = Descent.new(player, 8)
        Descent.clearFloor(run)
        Descent.advance(run)
        Descent.clearFloor(run)

        local out = Descent.account(player, run)
        assert(out.floors == 2, "the account says how far the run got")
        assert(player.deepest == deepest, "no depth record is written")
        assert(player.prestige == prestige, "and no prestige: levels are earned in the fighting now")
        assert(next(player.standing) == nil, "nor standing with any house")
    end },

    { name = "the account names the circles the run beat", fn = function()
        -- What a run has to show for itself, now that there is nowhere to bank it: which circles it
        -- actually beat, reported once on the terminal card and then gone with the run.
        local Quest = require("models.quest")
        local player = Player.new()
        local run = Descent.new(player, 5150)

        -- A CIRCLE IS BEATEN WHEN ITS GENERAL IS. She stands on the last floor of her stratum, so
        -- clearing a floor above hers credits nothing -- getting past her honour guard is not getting
        -- past her, and the terminal card would otherwise name a circle beaten a floor early.
        local first = Descent.sinAt(run, 1).vendor
        Descent.clearFloor(run)
        if Descent.FLOORS_PER_CIRCLE > 1 then
            assert((run.standing[first] or 0) == 0,
                "a lieutenant's floor is not the circle: nothing is credited yet")
        end
        for _ = 1, Descent.FLOORS_PER_CIRCLE - 1 do
            Descent.advance(run)
            Descent.clearFloor(run)
        end
        assert(run.standing[first] == 1, "beating the general credits the circle, once")

        Descent.advance(run)
        local second = Descent.sinAt(run, Descent.depth(run)).vendor
        assert(second ~= first, "and the next stratum is a different circle")
        for _ = 1, Descent.FLOORS_PER_CIRCLE do
            Descent.clearFloor(run)
            if _ < Descent.FLOORS_PER_CIRCLE then Descent.advance(run) end
        end

        local out = Descent.account(player, run)
        assert(out.circles[first] == 1 and out.circles[second] == 1,
            "the account names every circle the run cleared")
        -- ...and the campaign's shelf is not among the things it moved. Quest.sponsorProgress still adds
        -- a `standing` term, and it must read zero forever now that only completed quests feed it.
        assert(Quest.sponsorProgress(player, first) == 0,
            "a descent must not open a campaign shelf: the two modes share no progression")

        -- The account is a COPY, not the run's own table -- the terminal reads it after the run is gone.
        out.circles[first] = 99
        assert(run.standing[first] == 1, "the account must not alias the run it describes")
    end },

    { name = "standing survives a resume, because a resume is not an extraction", fn = function()
        -- Quitting on floor four and continuing must not hand the three circles below back at zero.
        -- The unbanked standing therefore rides in the run's snapshot with everything else.
        local run = Descent.new(nil, 2024)
        Descent.clearFloor(run)
        Descent.advance(run)
        Descent.clearFloor(run)
        local restored = Descent.restore(reserialize(Descent.snapshot(run)))
        for vendorId, n in pairs(run.standing) do
            assert(restored.standing[vendorId] == n,
                "a resumed run lost its unbanked standing with " .. vendorId)
        end
    end },

    { name = "a run's profile is a player the whole stack can run, and writes its own file", fn = function()
        -- The one thing that makes a descent's company safe: it is Player-shaped, so states/game.lua and
        -- everything under it runs a descent unchanged -- and it carries `saveFile`, so every Player.save
        -- in the game writes it to the descent's file instead of the campaign's.
        local Save = require("models.save")

        local profile = Descent.newProfile(Descent.startingCompany())

        assert(profile.saveFile == Descent.FILE, "a run's company must never write save.lua")
        assert(profile.saveFile ~= Save.FILE, "...which means its file is not the campaign's")
        -- EMPTY. The player is a tactician and stands in no company (models/descent.lua), so there is
        -- no body that is theirs and nothing walks in -- the gate is where a company starts existing
        -- (Gate.canDescend refuses the stair until it does).
        assert(#profile.roster == 0, "a descent opens with nobody on the roster")
        assert(#profile.lastDeployed == 0, "and nobody pre-selected for a deployment that cannot happen")

        -- Nothing a campaign would have accumulated comes in with it.
        assert(#profile.stash == 0, "a clean run carries no stash in")
        assert(next(profile.materials) == nil, "nor forging stock")
        assert(next(profile.completedQuests) == nil, "nor a campaign's finished quests")
        assert(profile.deepest == 0 and next(profile.standing) == nil, "nor any record of a past run")
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
            for _, band in ipairs({ "guardian", "minor" }) do
                assert(sin[band], sin.id .. " has no " .. band .. " to hold a stair")
                for _, key in ipairs({ "lead", "filler" }) do
                    local id = sin[band][key]
                    assert(Character.defs[id], sin.id .. "'s " .. band .. " " .. key .. " '" ..
                        tostring(id) .. "' is not a character blueprint")
                end
            end
            -- THE LIEUTENANT IS THE GENERAL'S OWN HONOUR GUARD, PROMOTED. Not decoration: it is what
            -- lets a player read their progress off the board -- the body that barred a stair two floors
            -- ago is standing behind her when they reach her -- and it is why fifteen floors needed no
            -- new blueprints. If the two ever drift apart, that reading is gone and nothing else says so.
            assert(sin.minor.lead == sin.guardian.filler,
                sin.id .. "'s lieutenant is no longer the body that fills out her own stair")
        end
    end },

    { name = "a circle owns a contiguous stratum, and all seven are dealt once", fn = function()
        -- A SHUFFLE, not a per-floor pick. The distinction is the feature: a pick lets a run draw
        -- Wrath three times and never reach Envy, and the descent stops being a tour of the circles.
        --
        -- And a circle owns a RUN of floors, all on her ground -- so the sequence of floors has to be
        -- seven contiguous blocks, never interleaved. Checked across many seeds because a single one
        -- could be a lucky permutation.
        for seed = 1, 40 do
            local run = Descent.new(nil, seed)
            local order, seen = {}, {}
            for floor = 1, Descent.CIRCLE_FLOORS do
                local sin = Descent.sinAt(run, floor)
                if order[#order] ~= sin.id then
                    assert(not seen[sin.id],
                        "seed " .. seed .. " comes back to " .. sin.id .. ": a circle's floors are split")
                    seen[sin.id] = true
                    order[#order + 1] = sin.id
                end
                -- Every floor of a stratum is fought on its sin's own ground, which is the thing that
                -- makes a stratum read as one place rather than as N floors that happen to be adjacent.
                assert(Descent.biomeAt(run, floor) == sin.biome,
                    "seed " .. seed .. " floor " .. floor .. " is not on " .. sin.id .. "'s ground")
            end
            assert(#order == #Descent.SINS, "seed " .. seed .. " deals " .. #order .. " circles, not seven")
        end
    end },

    { name = "a stratum is a descent toward its general, not interchangeable floors", fn = function()
        -- Every floor has a boss; only the LAST floor of a circle has the sin herself, and only she
        -- speaks. Walked over a whole run rather than read off the table, because what can break is the
        -- dispatch in floorQuest.
        local run = Descent.new(Player.new(), 2024)
        local generals = 0
        for floor = 1, Descent.CIRCLE_FLOORS do
            run.floor = floor
            local sin = Descent.sinAt(run, floor)
            local obj = Descent.floorQuest(run).map.objective
            local lead = obj.composition({})[1]

            if Descent.isGeneralFloor(floor) then
                generals = generals + 1
                assert(lead == sin.guardian.lead, "floor " .. floor .. " should be " .. sin.id .. " herself")
                assert(obj.opening == sin.scene, "and she speaks on her own stair")
            else
                assert(lead == sin.minor.lead,
                    "floor " .. floor .. " should be held by " .. sin.id .. "'s honour guard")
                -- She must NOT speak here: her scene played by a lieutenant would have the general
                -- talking through a body she is standing two floors below.
                assert(obj.opening == nil, "floor " .. floor .. " opens in silence")
            end
        end
        assert(generals == #Descent.SINS, "every circle gets exactly one general floor")
    end },

    { name = "under the seventh circle there is a bottom, and it is not a sin", fn = function()
        -- A DESCENT ENDS. This case replaced one that asserted the opposite -- that the deck was dealt
        -- again past the seventh, forever -- which was the endless reading the design has since
        -- dropped: the run ends by beating the thing the seven circles were in front of, the shape
        -- Hades and Dream Quest both use.
        local run = Descent.new(nil, 4242)
        assert(Descent.CIRCLE_FLOORS == #Descent.SINS * Descent.FLOORS_PER_CIRCLE,
            "the circles cover a stratum each")
        assert(Descent.FLOORS == Descent.CIRCLE_FLOORS + 1,
            "a descent is the seven circles' floors and the bottom under them")
        -- Fifteen at two floors per circle, which is Wizardry's band. Asserted as a range rather than a
        -- number so retuning FLOORS_PER_CIRCLE does not have to come and edit this line, but a change
        -- that took the mode back to a tour of eight -- or out to a twenty-two-floor slog -- still trips.
        assert(Descent.FLOORS >= 10 and Descent.FLOORS <= 17,
            "a descent is " .. Descent.FLOORS .. " floors, outside the depth this mode is built for")
        for floor = 1, Descent.CIRCLE_FLOORS do
            assert(not Descent.isBottom(floor), "floor " .. floor .. " is a circle, not the bottom")
            assert(Descent.sinAt(run, floor), "and it has a sin")
        end
        assert(Descent.isBottom(Descent.FLOORS), "the last floor is the bottom")
        assert(Descent.sinAt(run, Descent.FLOORS) == nil, "which is not anybody's circle")
        assert(Descent.biomeAt(run, Descent.FLOORS) == "underworld",
            "and is fought where the campaign always fought its ending")
        assert(Descent.nameOf(run, Descent.FLOORS):find("Hollow Crown"),
            "the landing has to be able to name what is down there")
    end },

    { name = "the last floor stands the Hollow Crown on it, and says the run ends there", fn = function()
        -- Lifted from data/quests/quest_the_gate_below.lua rather than reinvented: the campaign
        -- reaching the same body by a different road is not a reason to author it twice. What must be
        -- true is that the descriptor says the run ENDS -- states/game.lua reads that rather than
        -- counting floors, so the state never has to learn how long a descent is.
        local run = Descent.new(nil, 77)
        run.floor = Descent.FLOORS
        local quest = Descent.floorQuest(run)
        assert(quest.endsDescent, "the bottom must announce itself as the end of the run")
        assert(quest.sponsor == nil, "the last floor is not anybody's errand")

        local obj = quest.map.objective
        assert(obj.win and obj.win.type == "assassinate", "the Crown is killed, not cleared")
        assert(obj.win.target == "character_demon_lord", "and it is the Crown that has to die")
        assert(obj.opening, "it gets to speak first -- by the outro an assassinate target is dead")
        local bodies = obj.composition({})
        assert(bodies[1] == "character_demon_lord", "the Crown leads its own fight")
        assert(#bodies >= 3, "with its honour guard around it")

        -- Every circle above it still ends in an ordinary guardian and another landing.
        local mid = Descent.new(nil, 77)
        mid.floor = 3
        assert(not Descent.floorQuest(mid).endsDescent, "a circle is not the bottom")
    end },

    { name = "a run lays out the same circles from the same seed, forever", fn = function()
        -- The determinism the resume rests on: a run is saved as a seed and a depth, and everything
        -- else is re-derived. Two runs on one seed must agree, and a run must still agree with itself
        -- after a round trip through the serializer.
        local a, b = Descent.new(nil, 777), Descent.new(nil, 777)
        for floor = 1, #Descent.SINS do
            assert(Descent.sinAt(a, floor).id == Descent.sinAt(b, floor).id,
                "two runs on seed 777 disagree about floor " .. floor)
        end
        local restored = Descent.restore(reserialize(Descent.snapshot(a)))
        for floor = 1, #Descent.SINS do
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
        -- Pinned per FLOOR: floor 1 is the authored board and every floor under it is wider by a rule
        -- (Descent.floorDims), which tests/descent_floor_spec.lua walks the whole run of.
        local pinCols, pinRows = Descent.floorDims(1)
        assert(quest.map.cols == pinCols and quest.map.rows == pinRows,
            "the board is pinned, never derived")
        assert(quest.map.cacheCount, "the cache count is pinned too -- derived, it triples with density")

        local obj = quest.map.objective
        assert(not obj.meet, "the stair is fought now, not walked onto")
        assert(obj.win and obj.win.type == "killAll", "and it is won by clearing it")
        local bodies = obj.composition({})
        -- Floor 1 is the FIRST floor of the first circle, so it is held by her honour guard rather than
        -- by her. Both are the circle's own house either way, which is what this case is about.
        assert(bodies[1] == sin.minor.lead, "the stair is held by this house's own body")
        assert(#bodies >= 2, "even a lieutenant's stair is a set-piece, not a skirmish")

        -- Deeper stairs are held harder. Read off the floor rather than off prestige, so this is a
        -- statement about how far down the party went.
        local deep = Descent.new(nil, 31337)
        deep.floor = Descent.CIRCLE_FLOORS
        local deepBodies = Descent.floorQuest(deep).map.objective.composition({})
        assert(#deepBodies > #bodies, "the last circle's stair must be held harder than the first's")
    end },

    { name = "every circle stands its general on the stair and lets her speak", fn = function()
        -- The scene is the only seam an antagonist has, and a missing one is silent rather than loud:
        -- states/game.lua passes `opening` straight through and a nil plays nothing. So it is asserted
        -- here, against the registry, for all seven -- plus the bottom, which is the one floor whose
        -- speaker is not a sin.
        local Conversation = require("models.conversation")
        for i, sin in ipairs(Descent.SINS) do
            assert(sin.scene, sin.id .. " has no scene: its general would hold the stair in silence")
            local def = Conversation.defs[sin.scene]
            assert(def, sin.id .. " names a scene that does not exist: " .. tostring(sin.scene))
            -- One speaker and no companion blocks. A descent's company is generic bodies
            -- (models/descent_recruit.lua), so a `when = { has = }` block could never fire and an
            -- avatar line would be spoken by somebody who is not in the room.
            assert(#def.cast == 1 and def.cast[1] == sin.guardian.lead,
                sin.id .. "'s stair scene must be its own general alone")

            -- Her scene is handed to the fight on HER floor -- the last of her stratum -- and to no
            -- other floor of it.
            local run = Descent.new(nil, 4242)
            local floor
            for f = 1, Descent.CIRCLE_FLOORS do
                if Descent.sinAt(run, f).id == sin.id and Descent.isGeneralFloor(f) then floor = f break end
            end
            assert(floor, sin.id .. " has no general floor in a full descent")
            run.floor = floor
            assert(Descent.floorQuest(run).map.objective.opening == sin.scene,
                sin.id .. "'s floor does not hand her scene to the fight")
            assert(i == i) -- keeps the loop index meaningful to a reader of the failure message
        end

        local bottom = Descent.new(nil, 4242)
        bottom.floor = Descent.FLOORS
        local opening = Descent.floorQuest(bottom).map.objective.opening
        assert(Conversation.defs[opening], "the bottom's scene must exist too")
        assert(#Conversation.defs[opening].cast == 1,
            "the descent's Crown speaks alone: the campaign finale's scene is written for an avatar " ..
            "and companions, and a descent has neither")
    end },

    { name = "every floor is guarded, and the last one by the Demon Lord", fn = function()
        -- THE SHAPE OF A DESCENT IN ONE CASE: every floor has something standing on its stair, the
        -- circles' floors are held by their own house, and the bottom is the Demon Lord. Asserted by
        -- walking a real run rather than by reading the tables, because the thing that can break is the
        -- dispatch in floorQuest, not SINS.
        local run = Descent.new(Player.new(), 1717)
        for floor = 1, Descent.FLOORS do
            run.floor = floor
            local obj = Descent.floorQuest(run).map.objective
            assert(obj and obj.composition, "floor " .. floor .. " has nothing on its stair")
            local bodies = obj.composition({})
            assert(#bodies >= 2, "floor " .. floor .. "'s guard is a set-piece, not a skirmish")

            if not Descent.isBottom(floor) then
                local sin = Descent.sinAt(run, floor)
                local expected = Descent.isGeneralFloor(floor) and sin.guardian.lead or sin.minor.lead
                assert(bodies[1] == expected,
                    "floor " .. floor .. " is not led by " .. sin.id .. "'s own body")
                assert(obj.win.type == "killAll", "a circle's stair is taken by clearing it")
            else
                assert(bodies[1] == "character_demon_lord", "the last floor is the Demon Lord's")
                assert(obj.win.type == "assassinate" and obj.win.target == "character_demon_lord",
                    "and it ends when he does, honour guard standing or not")
            end
        end

        -- All seven generals stand on a floor, exactly one each, however the shuffle dealt them.
        local seen, generalFloors = {}, 0
        for floor = 1, Descent.CIRCLE_FLOORS do
            if Descent.isGeneralFloor(floor) then
                generalFloors = generalFloors + 1
                local lead = Descent.sinAt(run, floor).guardian.lead
                assert(not seen[lead], lead .. " guards two floors of the same descent")
                seen[lead] = true
            end
        end
        assert(generalFloors == #Descent.SINS, "seven generals, seven general floors")
        for _, sin in ipairs(Descent.SINS) do
            assert(seen[sin.guardian.lead], sin.id .. "'s general is on no floor at all")
        end
    end },

    { name = "a floor carries the way back up, on the tile the party walks in on", fn = function()
        -- THE RETREAT (models/overworld.lua's placeExit). An expedition ends by WALKING BACK to the
        -- stair it came down by, which is what bounds how deep a company pushes -- the return trip is
        -- real ground it has to have something left for. A campaign ground must not grow one: a quest is
        -- left for free by pressing Back, so a tile offering an exit there would offer nothing.
        local run = Descent.new(Player.new(), 808)
        local mp = Descent.floorQuest(run).map
        assert(mp.exitAtStart, "a descent floor asks for the way up")

        local grid = Overworld.generate({
            cols = mp.cols, rows = mp.rows, biome = mp.biome, seed = 808, ascent = true,
            keyCount = 0, encounterCount = mp.encounters, cacheCount = mp.cacheCount,
            encounters = { { kind = "combat", weight = 1 } },
            exitAtStart = mp.exitAtStart,
        })
        assert(grid:startCell().encounter and grid:startCell().encounter.kind == "ascent",
            "the way up stands on the start tile, so it has to be walked back to")

        -- Placed LAST, so it can never have displaced a stop or been counted as one.
        local stops = 0
        for y = 1, grid.rows do
            for x = 1, grid.cols do
                local e = grid.cells[y][x].encounter
                if e and e.kind ~= "ascent" then stops = stops + 1 end
            end
        end
        assert(stops >= mp.encounters.min, "the exit ate a stop: only " .. stops .. " left")

        local plain = Overworld.generate({
            cols = 15, rows = 13, biome = "forest", seed = 808, encounterCount = { min = 8, max = 8 },
            encounters = { { kind = "combat", weight = 1 } },
        })
        local pe = plain:startCell().encounter
        assert(not (pe and pe.kind == "ascent"),
            "a campaign ground grows no exit tile: leaving one is already free")
    end },

    { name = "a floor is a dungeon, and it is deep enough to be one", fn = function()
        -- THE CARVE (models/layouts/dungeon.lua). A descent floor used to inherit its biome's layout,
        -- which meant it inherited a campaign GROUND -- open country with a road through it -- and its
        -- deepest point sat NINETEEN tiles from the entrance. Two seconds of walking, out and back. A
        -- way up worth returning to, ground worth mapping and anywhere for a chute to drop you all need
        -- distance, and there was none.
        --
        -- Asserted on DEPTH rather than on the layout id, because naming the layout proves only that a
        -- string was passed. What has to hold is the thing the string was for.
        local run = Descent.new(Player.new(), 909)
        local mp = Descent.floorQuest(run).map
        assert(mp.carve == "dungeon" and mp.spacing, "a floor names its own carve and its own spacing")

        for seed = 1, 4 do
            local grid = Overworld.generate({
                biome = mp.biome, cols = mp.cols, rows = mp.rows,
                layout = mp.carve, spacing = mp.spacing,
                seed = seed, ascent = true, keyCount = 0,
                encounterCount = mp.encounters, cacheCount = mp.cacheCount,
                encounters = { { kind = "combat", weight = 3 }, { kind = "treasure", weight = 1 } },
            })

            local walk = 0
            for y = 1, grid.rows do
                for x = 1, grid.cols do
                    if grid:typeWalkable(grid.cells[y][x].tile) then walk = walk + 1 end
                end
            end
            local reach = 0
            for _ in pairs(grid:reachable()) do reach = reach + 1 end
            -- The carve owns connectivity and nothing downstream repairs it: a board in pieces reads as
            -- a small board rather than as a bug, which is exactly why this is asserted rather than
            -- assumed.
            assert(reach == walk, "seed " .. seed .. ": " .. (walk - reach) .. " tiles stranded")

            local far = 0
            for _, d in pairs(grid:bfsDistances(grid:startCell())) do if d > far then far = d end end
            -- Bounds, not a target. The floor is around 42 tiles deep as tuned; 30 is well clear of the
            -- 19 the biome layouts gave and is the line below which the walk back stops being a walk.
            assert(far >= 30, "seed " .. seed .. ": deepest point is " .. far ..
                " tiles -- a floor you can cross this fast is a courtyard, not a dungeon")
            assert(walk >= 280, "seed " .. seed .. ": only " .. walk ..
                " walkable tiles -- there is not enough floor to get lost on")
        end
    end },

    { name = "a circle's house is a real vendor with a real shop, gated on that circle", fn = function()
        -- THE JOIN THE CITY NOW GROWS ON. Each of the seven shops IS one of the sins, so beating a
        -- circle's general opens that shelf in the city (states/game.lua's openLanding writes
        -- `player.standing[vendorId]`, models/building.lua reads it).
        --
        -- Asserted from the DESCENT's side as well as the city's, because the join has two ends and a
        -- rename at either one breaks it silently: a sin naming a vendor with no building would credit a
        -- house that does not exist, and the toast would name nothing.
        local Building = require("models.building")
        local Vendor = require("models.vendor")
        for _, sin in ipairs(Descent.SINS) do
            local vendor = Vendor.get(sin.vendor)
            assert(vendor, sin.id .. " names a vendor that does not exist: " .. tostring(sin.vendor))
            assert(vendor.sin == sin.id,
                sin.vendor .. " claims sin '" .. tostring(vendor.sin) .. "' while " .. sin.id ..
                " claims it -- the join disagrees with itself")
            local building = Building.defs[sin.vendor]
            assert(building, sin.id .. "'s house has no card in the city")
            assert(building.unlockCircle,
                sin.vendor .. " is not gated on its circle, so beating " .. sin.id .. " opens nothing")
            assert(building.vendor == sin.vendor,
                "the card and the shelf must be the same house")
        end
    end },

    { name = "a boon undealt on a landing survives a save and is not re-dealt", fn = function()
        -- The landing is the beaten general's boon (states/game.lua's openLanding). The slate is pinned
        -- to the RUN for two reasons and this pins both: a landing re-opened must deal the same three
        -- cards, and a run saved standing on one has a decision outstanding that has to survive the
        -- round trip -- otherwise quitting there loses the boon and comes back to a cleared floor with
        -- no panel and no stair.
        local run = Descent.new(Player.new(), 606)
        run.landing = { "relic_honed_edge", "relic_alms_bowl", "relic_long_watch" }
        local back = Descent.restore(reserialize(Descent.snapshot(run)))
        assert(back.landing and #back.landing == 3, "the undealt slate rides in the save")
        for i, id in ipairs(run.landing) do
            assert(back.landing[i] == id, "and comes back as the same three cards, in order")
        end

        -- ...and NIL at every other moment, which is what tells a resume there is no panel to re-open.
        local mid = Descent.new(Player.new(), 606)
        assert(Descent.restore(reserialize(Descent.snapshot(mid))).landing == nil,
            "a run not standing on a landing carries no slate")
    end },

    { name = "the account reports two floor numbers and names neither ending", fn = function()
        -- Descent.account replaced Descent.extract. A run that ended well and one that ended badly count
        -- different things: `floors` is what the company BEAT, `depth` is where it was standing. A wipe
        -- on floor 2 cleared one, and reporting two would credit the fight that killed them.
        assert(Descent.extract == nil, "extraction is gone, not kept alive beside its heir")

        local player = Player.new()
        local run = Descent.new(player, 77)
        Descent.clearFloor(run)   -- beat floor 1
        Descent.advance(run)      -- ...and step onto floor 2, where the company now stands

        local out = Descent.account(player, run)
        assert(out.floors == 1, "`floors` is what the company beat")
        assert(out.depth == 2, "`depth` is where it was standing")
        assert(out.title == nil and out.outcome == nil,
            "the account carries no title: how a run ended is the caller's knowledge, not this table's")
    end },
}
