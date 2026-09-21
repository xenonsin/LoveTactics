-- THE CHEST THAT IS A MONSTER (models/mimic.lua, Overworld:placeTraps' third half).
--
-- The feature is one sentence -- some lids are alive, and the one that is fights you with the chest's
-- own contents -- and every part of it that can rot does so silently:
--
--   * WHICH lids are alive is decided AT GENERATION, because a floor is a place the company keeps a
--     map of. Decided at the lid it would be re-askable by stepping off the tile and back onto it, and
--     would answer differently on the second trip down.
--   * a chest holds a HAUL, and the haul is the fight. Two or three pieces at the floor's own rank
--     (Spoils.cache), pinned onto the cell the first time anybody looks -- because those pieces are
--     also the body's kit, so an unpinned roll would be re-rolling the encounter itself.
--   * a lid is either WIRED or ALIVE, never both: a mimic never reaches the collect a trap springs on,
--     so a wired mimic is a flag that does nothing.
--   * the fight is dealt by NOTHING. A mimic that could turn up as a marked fight on open ground is a
--     monster that is sometimes disguised, and the disguise is the monster.
--   * ONE LIST, READ TWICE. `carried` arms the body and pays the win. Two lists would be two ledgers,
--     and the sentence the whole thing is built on -- it hits you with what it is sitting on -- would
--     become a coincidence of tuning rather than a fact about the data.
--   * it does not RE-ARM. Descent.rearmFloor wakes cleared fights; a body that re-deals a chest's
--     contents every trip down is a printing press.
--
-- Pure logic, headless.

local Mimic = require("models.mimic")
local Overworld = require("models.overworld")
local Descent = require("models.descent")
local Encounter = require("models.encounter")
local EncounterBattle = require("models.encounter_battle")
local Character = require("models.character")
local Growth = require("models.growth")
local Item = require("models.item")
local Trap = require("models.trap")
local Spoils = require("models.spoils")

-- A board of nothing but chests, so no case here is a coin flip on whether the fixture laid one.
local function chestFloor(seed, opts)
    opts = opts or {}
    return Overworld.generate({
        biome = "forest", cols = 13, rows = 13, seed = seed,
        encounterCount = 14, cacheCount = 2, keyCount = 0, ascent = true,
        trapCount = { min = 0, max = 0 }, -- no bad road: every case here is about lids
        trappedChestChance = opts.trappedChestChance,
        mimicChance = opts.mimicChance,
        encounters = { { kind = "treasure", weight = 1 } },
    })
end

local function chests(grid)
    local out = {}
    for y = 1, grid.rows do
        for x = 1, grid.cols do
            local e = grid.cells[y][x].encounter
            if e and e.kind == "treasure" then out[#out + 1] = e end
        end
    end
    return out
end

-- A chest's worth of real, ordinary gear -- the shape a floor actually hands over. THREE, because the
-- plural is the feature: a mimic swings what the chest was holding, so a one-item chest stands up as a
-- box with a bite and nothing else (Spoils.CACHE_PIECES).
local HAUL = { "consumable_healing_potion", "weapon_iron_sword", "armor_leather_armor" }

local function names(char)
    local out = {}
    for _, item in ipairs(Character.eachItem(char)) do out[#out + 1] = item.id end
    return out
end

local function has(list, id)
    for _, v in ipairs(list) do if v == id then return true end end
    return false
end

local function count(list, id)
    local n = 0
    for _, v in ipairs(list) do if v == id then n = n + 1 end end
    return n
end

return {
    { name = "the floor decides which lids are alive, and the mark rides the lid", fn = function()
        local grid = chestFloor(31337, { mimicChance = 100 })
        local found = chests(grid)
        assert(#found > 0, "the fixture laid no chests -- this case proves nothing")
        for _, e in ipairs(found) do
            assert(e.mimic == true, "a chest on a floor asking for every lid alive is still dead wood")
        end
        -- ON THE ENCOUNTER, NOT THE CELL, exactly as a wired lid is: a mimic is a property of the thing
        -- with the lid and not of the ground it stands on, so the mark rides wherever the encounter does
        -- (into the save, onto a kept floor, back out on the next trip down).
        for y = 1, grid.rows do
            for x = 1, grid.cols do
                assert(not grid.cells[y][x].mimic, "the mark was written onto the ground")
            end
        end
    end },

    { name = "a board that never mentions mimics grows none", fn = function()
        -- The authored campaign passes no `mimicChance` at all, and a quest whose chests quietly turned
        -- into elite fights would be a difficulty change nobody wrote.
        for _, e in ipairs(chests(chestFloor(5150))) do
            assert(not e.mimic, "a board that never asked for a mimic got one")
        end
        for _, e in ipairs(chests(chestFloor(5150, { mimicChance = 0 }))) do
            assert(not e.mimic, "a board that asked for none got one anyway")
        end
    end },

    { name = "a lid is either wired or alive, and never both", fn = function()
        -- Both dials at 100, which is the only setting that can prove the exclusion rather than fail to
        -- disprove it: at anything less, "no chest carries both" is satisfied by luck.
        local grid = chestFloor(31337, { mimicChance = 100, trappedChestChance = 100 })
        local found = chests(grid)
        assert(#found > 0, "the fixture laid no chests")
        for _, e in ipairs(found) do
            assert(e.mimic, "the mimic pass must run FIRST, or the wiring has nothing to skip")
            assert(not e.trapped, "a mimic was wired as well. The trap springs on the collect and a "
                .. "mimic never reaches one, so this is a flag that silently does nothing")
        end

        -- ...and the wiring is not simply broken: the same board with no mimics asked for wires the lot.
        for _, e in ipairs(chests(chestFloor(31337, { trappedChestChance = 100 }))) do
            assert(e.trapped and Trap.defs[e.trapped],
                "with no mimics in the way, every chest should still be wired")
        end
    end },

    { name = "nothing in the game deals the mimic fight onto a tile", fn = function()
        -- The premise: the ONLY way to meet one is to open the wrong chest. A weight above zero anywhere
        -- would put a plainly-marked mimic on open ground, and the disguise is the whole monster.
        assert(Encounter.get(Mimic.ENCOUNTER), "the mimic's encounter blueprint is gone")
        for day = 1, 40 do
            for _, e in ipairs(Encounter.pool({ day = day, biome = "underworld" })) do
                assert(e.id ~= Mimic.ENCOUNTER,
                    "the mimic fight is in the rolled pool at day " .. day)
            end
        end
    end },

    { name = "springing the lid rewrites the tile as the fight, carrying the chest whole", fn = function()
        local sprung = Mimic.spring({ kind = "treasure", mimic = true, tier = 2 }, HAUL)
        assert(sprung.id == Mimic.ENCOUNTER, "the sprung stop names no fight")
        assert(sprung.kind == "elite", "a mimic is an elite: an ordinary fight's husk chance is half a "
            .. "treasure's, so springing the lid would quietly cost the company a sealed find")
        assert(sprung.name == "Mimic", "the sprung fight is still calling itself a chest")
        assert(sprung.tier == 2, "the ground's tier did not ride across, so the payout moved")
        assert(Encounter.get(sprung.id).composition[1] == Mimic.BODY, "the fight fields no mimic")

        -- THE CHEST, WHOLE. Every id the lid was holding, owed by the body that was pretending to be it.
        local owed = Mimic.owed(sprung)
        assert(#owed == #HAUL, "the chest lost something on the way into the fight")
        for _, id in ipairs(HAUL) do assert(has(owed, id), id .. " is not owed by the fight") end

        -- COPIED, NOT ALIASED: this list is written into a saved cell and paid out on a win, and the
        -- caller's table is the chest's own.
        assert(sprung.carried[Mimic.BODY] ~= HAUL, "the fight aliases the chest's own list")
    end },

    { name = "the body is armed with exactly what it will drop", fn = function()
        local bare = Growth.spawn(Mimic.BODY, 1, 1)
        assert(has(names(bare), "weapon_mimic_bite"), "the mimic lost its own weapon")

        local armed = Growth.spawn(Mimic.BODY, 1, 1, HAUL)
        local kit = names(armed)
        assert(has(kit, "weapon_mimic_bite"), "arming it with the chest took its bite away")
        for _, id in ipairs(HAUL) do
            assert(has(kit, id), "the mimic is not holding " .. id .. ", which it will hand over on death")
        end

        -- ROOM FOR A CHEST. The blueprint carries ONE item on purpose; if somebody fills its grid the
        -- feature stops working with no error anywhere -- the body simply fights bare and the win still
        -- pays, and the sentence this is all built on quietly stops being true.
        local def = Character.defs[Mimic.BODY]
        local authored = 0
        for _, entry in ipairs(def.startingItems or {}) do if entry then authored = authored + 1 end end
        assert(Character.MAX_INVENTORY - authored >= 4,
            "the mimic's blueprint grid is full: a chest has nowhere to go")

        -- An id the catalogue does not know is dropped rather than instantiated.
        local junk = Growth.spawn(Mimic.BODY, 1, 1, { "weapon_not_a_real_item" })
        assert(#names(junk) == authored, "a typo in a drop list reached Item.instantiate")
    end },

    { name = "the win hands over what it was holding, on top of what it rolled", fn = function()
        local sprung = Mimic.spring({ kind = "treasure", mimic = true, tier = 1 }, HAUL)
        local spoils = EncounterBattle.spoils({ encounter = sprung, day = 1, floorLevel = 1 })
        assert(spoils and spoils.loot, "a won mimic paid nothing at all")
        for _, id in ipairs(HAUL) do
            assert(has(spoils.loot, id), "the win did not hand over " .. id .. ", which the company had "
                .. "just been hit with")
        end

        -- ON TOP OF THE ROLL, not instead of it. `loot` on an encounter SHORT-CIRCUITS the roll (it is
        -- somebody's exact figure for the whole payout); this is an inventory, and a fight that swapped
        -- the one for the other would be the mimic paying LESS than the ordinary elite it is.
        assert(sprung.loot == nil, "the sprung fight authored a loot override, which kills its own roll")

        -- ...and a stackable owed twice is owed twice, which is what a chest of two potions means.
        local pair = Mimic.spring({ kind = "treasure", mimic = true },
            { "consumable_healing_potion", "consumable_healing_potion" })
        local paid = EncounterBattle.spoils({ encounter = pair, day = 1 })
        assert(count(paid.loot, "consumable_healing_potion") >= 2, "a chest of two paid one")
    end },

    { name = "a settled mimic is not woken with the rest of the floor", fn = function()
        -- The floor's own fights re-arm on the next trip down (the monsters come back, the places do
        -- not). A mimic is both, and it settles as the PLACE: a chest pays once.
        local grid = {
            rows = 1, cols = 3,
            cells = { {
                { encounter = { kind = "elite", id = "encounter_elite" }, cleared = true },
                { encounter = Mimic.spring({ kind = "treasure", mimic = true }, HAUL), cleared = true },
                { encounter = { kind = "treasure" }, cleared = true },
            } },
        }
        local woken = Descent.rearmFloor(grid)
        assert(grid.cells[1][1].cleared == nil, "the floor's ordinary elite did not re-arm")
        assert(grid.cells[1][2].cleared == true,
            "the mimic woke up and is holding the chest's contents again -- a printing press")
        assert(grid.cells[1][3].cleared == true, "a spent cache re-armed")
        assert(woken == 1, "the count of woken fights includes the mimic")
    end },

    { name = "every floor of the rift asks for them, at a rate that leaves opening a chest right", fn = function()
        -- Below about a tenth nobody ever meets one and the whole stop is a rumour; above a third,
        -- opening a chest is simply a mistake -- and a reward whose correct play is to walk past it is
        -- not a reward. The wired lid sits at a third BECAUSE it is cheap to answer; this is a whole
        -- set-piece, and wants to be rarer than the thing that costs a few points of health.
        assert(Mimic.CHANCE >= 10, "at " .. Mimic.CHANCE .. "% a mimic is a rumour")
        assert(Mimic.CHANCE < Descent.TRAPPED_CHEST_CHANCE,
            "a mimic costs a whole fight and a wire costs a toast; the fight must be the rarer of the two")

        local Player = require("models.player")
        local player = Player.new()
        local run = Descent.new(player, 4242)
        for floor = 1, Descent.FLOORS do
            run.floor = floor
            local mp = Descent.floorQuest(run, player).map
            assert(mp.mimicChance == Mimic.CHANCE,
                "floor " .. floor .. " asks for " .. tostring(mp.mimicChance) .. " live lids")
        end
    end },

    { name = "a REAL floor, generated the way the game generates one, has live lids on it", fn = function()
        -- THE WIRING, NOT THE GENERATOR. Every case above drives Overworld.generate with params of its
        -- own, which tests the pass; what carries a floor's request TO that pass is a different
        -- question, and it is the one that hid the traps, the locks, the holes and the vaults from
        -- every floor for a week (tests/floor_features_spec.lua). So this builds the params the way
        -- states/game.lua does -- off the floor descriptor, through the copier -- and looks for a
        -- mimic on the board that comes back.
        local Player = require("models.player")
        local player = Player.new()
        -- FIFTEEN FLOORS ACROSS THREE SAVES, and the sample size is the case rather than a detail.
        -- A lid is alive at Mimic.CHANCE (20%), so six floors laid about ten chests and the odds of
        -- none of them being alive were 0.8^10 -- better than one run in ten. This spec duly went red
        -- on a change that touched nothing it is about: a new `require` reordered `pairs` over a
        -- registry, the rng stream behind the floor pool shifted with it, and the sample landed in its
        -- own tail. Nothing was broken and the failure named the wiring.
        --
        -- Fifty-odd chests puts that at 0.8^50, which is about one run in seventy thousand. The claim
        -- is unchanged -- the floor asks for mimics and something carries the request across -- and it
        -- is now a claim the spec can actually hold.
        local live, lids = 0, 0
        for _, save in ipairs({ 90210, 31337, 4242 }) do
        local run = Descent.new(player, save)
        for floor = 1, 15 do
            run.floor = floor
            local mp = Descent.floorQuest(run, player).map
            local grid = Overworld.generate(Descent.applyFloorFeatures({
                biome = mp.biome, cols = mp.cols, rows = mp.rows, seed = 4000 + floor,
                -- The floor's own reweighted pool, exactly as states/game.lua hands it over -- `mp
                -- .encounters` is the STOP COUNT, not the pool.
                encounters = Descent.floorPool({ biome = mp.biome, day = 20, prestige = 10 }),
                encounterCount = { min = 14, max = 14 },
                cacheCount = mp.cacheCount, keyCount = mp.keyCount, ascent = mp.ascent,
                secrets = mp.secrets, exitAtStart = mp.exitAtStart,
                objective = mp.objective, objectives = mp.objectives,
                combatBudget = mp.combatBudget,
            }, mp))
            for _, e in ipairs(chests(grid)) do
                lids = lids + 1
                if e.mimic then live = live + 1 end
            end
        end
        end
        assert(lids > 0, "real floors laid no chests at all -- retarget this case")
        assert(live > 0, "real floors laid " .. lids .. " chests and not one of them was alive. "
            .. "The pass runs and the floor asks for it, and nothing is carrying the request across")
    end },

    { name = "a chest is a HAUL, drawn at the floor's own rank", fn = function()
        -- The plural is load-bearing twice: it is what makes a cache worth the detour its marker
        -- advertises, and it is what a mimic is BUILT from -- a one-item chest stands up as a box with
        -- a bite and nothing else.
        assert(Spoils.CACHE_PIECES.min >= 2, "a chest that can hold one piece is not a haul, and the "
            .. "mimic it becomes is a body with nothing in its hands")
        assert(Spoils.CACHE_PIECES.max >= Spoils.CACHE_PIECES.min, "the cache range is inverted")

        -- Measured rather than read: the draw can come back short at a rank the catalogue is thin at,
        -- so the claim is about the DISTRIBUTION and has to be sampled.
        local short, deep = 0, 0
        for _ = 1, 60 do
            short = math.max(short, #Spoils.cache({ floorLevel = 1, day = 1 }))
            deep = math.max(deep, #Spoils.cache({ floorLevel = 20, day = 12 }))
        end
        assert(short >= 2, "a shallow chest never held more than one piece")
        assert(deep >= 2, "a deep chest never held more than one piece")

        -- THE FLOOR'S LAW BINDS A CHEST TOO (docs/shelf.md): nothing ranked deeper than the floor
        -- reaches. Asserted at the shallow end, which is where a symmetric band used to break it.
        local _, _, centre = Spoils.rankBand({ floorLevel = 1, day = 1 })
        for _ = 1, 40 do
            for _, id in ipairs(Spoils.cache({ floorLevel = 1, day = 1 })) do
                assert(Spoils.depthOf(Item.defs[id]) <= centre,
                    "floor one handed over " .. id .. ", which is ranked deeper than floor one reaches")
            end
        end
    end },

    { name = "the trophy is paid on a percent, on top of everything else, and only once", fn = function()
        local sprung = Mimic.spring({ kind = "treasure", mimic = true }, HAUL)
        assert(sprung.trophy and sprung.trophy.id == Mimic.TROPHY.id,
            "the sprung fight offers no chance at the body's own trophy")
        -- STAMPED ON THE CELL, not looked up at the till: a fight left standing and come back to two
        -- trips later must offer the same odds at the same piece.
        assert(sprung.trophy.chance == Mimic.TROPHY.chance, "the odds did not ride onto the cell")

        local Player = require("models.player")
        local player = Player.new()

        -- Measured over many wins, because the claim is about a RATE. What is asserted is only that it
        -- is neither never nor always: pinning the exact frequency would be a spec that reddens the day
        -- somebody tunes the number, which is the one day it must not.
        local got, runs = 0, 400
        for _ = 1, runs do
            local spoils = EncounterBattle.spoils({ encounter = sprung, day = 1, player = player })
            if has(spoils.loot, Mimic.TROPHY.id) then got = got + 1 end
        end
        assert(got > 0, "the trophy never dropped in " .. runs .. " wins -- the roll is not wired")
        assert(got < runs, "the trophy dropped every time; a percent that is really a guarantee")

        -- ON TOP, never instead: the chest is still handed over in the same breath.
        local withBoth = 0
        for _ = 1, 40 do
            local spoils = EncounterBattle.spoils({ encounter = sprung, day = 1, player = player })
            if has(spoils.loot, "weapon_iron_sword") then withBoth = withBoth + 1 end
        end
        assert(withBoth == 40, "a win that paid the trophy stopped paying the chest")

        -- ...AND REFUSED ONCE HELD. Every trophy in this family is best-not-sum, so a second copy is
        -- dead weight, and dealing dead weight would make the second of these fights pay less than an
        -- ordinary body does.
        Player.addToStash(player, Item.instantiate(Mimic.TROPHY.id))
        for _ = 1, 200 do
            local spoils = EncounterBattle.spoils({ encounter = sprung, day = 1, player = player })
            assert(not has(spoils.loot, Mimic.TROPHY.id),
                "a company that already holds the trophy was dealt a second one")
        end
    end },

    { name = "the trophy widens the company's bag, best rather than sum", fn = function()
        local Player = require("models.player")
        local Character = require("models.character")
        local player = Player.new()
        assert(Descent.carryMax(player) == Descent.CARRY_MAX,
            "a company carrying no bag reads as widened, which deletes the whole reward")

        local def = Item.defs[Mimic.TROPHY.id]
        assert((def.haulBonus or 0) > 0, "the trophy's own half does nothing on the road")

        -- IN THE PACK. The ceiling is a fact about the COMPANY, so which pocket it is in is not a
        -- decision anybody made -- the same reach Trap.detectRadiusFor and Player.visionBonus take.
        Player.addToStash(player, Item.instantiate(Mimic.TROPHY.id))
        local widened = Descent.CARRY_MAX + def.haulBonus
        assert(Descent.carryMax(player) == widened,
            "the bag in the packs did not widen the ceiling: " .. Descent.carryMax(player))

        -- ...AND IN A GRID, which is where it will actually live, since the same cell is what pays for
        -- it in a fight.
        local other = Player.new()
        Character.addItem(other.roster[1], Item.instantiate(Mimic.TROPHY.id))
        assert(Descent.carryMax(other) == widened, "the bag in a body's grid did not widen the ceiling")

        -- BEST, NOT SUM: two bags are not twice the bag. Without this the one item in the game that
        -- widens the ceiling would be farmable into an unbounded pack.
        Player.addToStash(player, Item.instantiate(Mimic.TROPHY.id))
        assert(Descent.carryMax(player) == widened, "two bags stacked into a bigger ceiling")

        -- AND THE ROOM MOVES WITH IT, which is the half a player actually meets: the refusal that keeps
        -- a chest shut reads this, and so does the "Carrying n / max" line that warns about it.
        local run = Descent.new(player, 1)
        assert(Descent.carryRoom(player, run) == Descent.carryMax(player) - Descent.carried(player, run),
            "the ceiling widened and the room did not")
    end },

    { name = "utility_still_hungry bites for what the company is carrying, and nothing when empty", fn = function()
        -- The item's own contract, and it is one sentence read by three surfaces: the grid badge, the
        -- tooltip row and the blow all go through `counter`, so what the player is told and what the
        -- bite is worth cannot drift apart.
        local Combat = require("models.combat")
        local Player = require("models.player")
        local def = Item.defs["utility_still_hungry"]
        assert(def and def.activeAbility and def.activeAbility.counter, "the gullet has no purse to read")

        local restore = Player.active
        local ok, err = pcall(function()
            local player = Player.new()
            Player.active = player
            -- The company as it walked in, which is what a real run stamps (Save.snapshot, states/game
            -- .lua). Built from the live company rather than from an empty table, or Rowan's own kit
            -- would read as this trip's haul and the fixture would start full.
            player.descentRun = { entry = require("models.save").snapshot(player) }

            local item = Item.instantiate("utility_still_hungry")
            local bearer = Character.instantiate("character_knight")
            Character.addItem(bearer, item)

            -- EMPTY IS REFUSED RATHER THAN WEAK. The haul is the ammunition, so a bite with none behind
            -- it would be a wasted turn dressed as an option -- and the refusal carries the authored
            -- sentence rather than the generic one.
            assert(def.activeAbility.counter(nil, item) == 0, "an empty gullet reads as full")
            local why = Combat.itemBlockReason({ char = bearer }, item)
            assert(why and why.text == def.activeAbility.counterEmpty,
                "an empty gullet does not say why it is greyed: " .. tostring(why and why.text))

            -- ...AND IT FILLS WITH THE TRIP. Six finds in the packs, six behind the bite.
            for _ = 1, 6 do Player.addToStash(player, Item.instantiate("weapon_iron_sword")) end
            assert(def.activeAbility.counter(nil, item) == 6,
                "six finds read as " .. def.activeAbility.counter(nil, item))

            -- CAPPED, so the two halves of the item cannot compound: `haulBonus` widens the ceiling,
            -- and an uncapped bite would be feeding its own damage off its own reward.
            for _ = 1, 20 do Player.addToStash(player, Item.instantiate("weapon_iron_dagger")) end
            local capped = def.activeAbility.counter(nil, item)
            assert(capped < Descent.carried(player, player.descentRun),
                "a bag of twenty-six put all of it behind one blow")
            assert(capped == 6, "the cap reads " .. capped)

            -- ...AND IT DOES NOT SPEND THE HAUL. The Gleaning Rod empties itself; this reads. Eating the
            -- company's finds would be the game destroying loot in front of the player, which is the
            -- exact thing the chest code refuses to do one file over.
            local before = Descent.carried(player, player.descentRun)
            def.activeAbility.counter(nil, item)
            assert(Descent.carried(player, player.descentRun) == before, "reading the gullet ate the haul")
        end)
        Player.active = restore
        assert(ok, err)
    end },

    { name = "the mimic's bite is creature kit and nothing else", fn = function()
        -- tests/bestiary_spec.lua holds the BODY to the creature contract; this holds the one item it
        -- was authored with, which is the half that would otherwise reach a shelf.
        local bite = Item.defs["weapon_mimic_bite"]
        assert(bite, "the mimic's own weapon is gone")
        assert(bite.class == "creature", "a mimic's bite is on somebody's shelf")
        assert(not bite.price, "a mimic's bite is priced, so a counter could stock it")
        assert(bite.noSteal, "a mimic's bite can be lifted off it -- creature kit never leaves the body")
        assert(not bite.dropTier, "a mimic's bite is in the floor's drop pool")
        assert(Character.defs[Mimic.BODY].defaultAction == "weapon_mimic_bite",
            "the mimic does not open with its own weapon")
    end },
}
