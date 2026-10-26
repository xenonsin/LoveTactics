-- THE RETURN TRIP: what a company comes back to, within a run and across runs.
--
-- THE RIFT RESETS EVERY RUN (2026-10-24). Within a run, a floor the company walked is kept on the run
-- (Descent.keepFloor), so the way up finds it as it was left and a save carries it. Across runs nothing
-- is kept: the next descent starts at floor one on new ground (Seed.run folds in which run this is). A
-- wipe ends the run and loses the haul (tests/wipe_spec.lua holds that half).
--
-- It used to hold the opposite -- that a wipe left the company on the floor it fell on, its haul held
-- by a carrier there -- and the carrier cases went with the persistent rift.

local Descent = require("models.descent")
local Player = require("models.player")
local Save = require("models.save")

-- A company standing on `floor`, having beaten everything above it.
local function runAt(player, floor, seed)
    local run = Descent.new(player, seed or 4242)
    for _ = 2, floor do
        Descent.clearFloor(run)
        Descent.advance(run)
    end
    return run
end

return {
    {
        name = "keeping a floor on the run does not move the company off it",
        fn = function()
            local player = Player.new()
            local run = runAt(player, 9)
            assert(Descent.depth(run) == 9, "the fixture stands on floor nine, got " .. Descent.depth(run))

            Descent.keepFloor(run, 9, { cols = 8, rows = 8, marker = "the board they stand on" })

            assert(Descent.depth(run) == 9,
                "keeping a floor must not move the company off floor nine, got " .. Descent.depth(run))
            assert(run.cleared == 8,
                "and the floor they stand on is not credited as beaten, got " .. tostring(run.cleared))
        end,
    },
    {
        -- THE GROUND IS THE ONE THEY WALKED, not a fresh roll of the same seed. A floor cannot be
        -- rebuilt from its seed (the stops are drawn in `pairs` order), so a return trip that re-rolled
        -- would open on ground the company had never seen -- which is the whole reason a board is kept
        -- rather than a seed. The pile this case used to look for is deleted; the board is the promise.
        name = "the board comes back exactly as it was walked",
        fn = function()
            local player = Player.new()
            local run = runAt(player, 5)
            Descent.keepFloor(run, 5, { cols = 8, rows = 8, marker = "walked" })

            local board = Descent.floorBoard(run, 5)
            assert(board and board.marker == "walked", "the floor they walked is kept")
        end,
    },
    {
        -- ...ACROSS A SAVE, mid-run. Board and depth have to survive together: either one coming back
        -- without the other is the way up to the wrong place, or to the right place on the wrong ground.
        name = "depth and the run's boards survive a save",
        fn = function()
            local player = Player.new()
            local run = runAt(player, 7)
            -- Both ride on the run again (2026-10-24): the board lives exactly as long as the run.
            Descent.keepFloor(run, 6, { cols = 8, rows = 8, marker = "six" })
            player.descentRun = run

            local restored = Save.restore(Save.snapshot(player))
            local back = restored.descentRun
            assert(back, "the run comes back at all")
            assert(Descent.depth(back) == 7, "on floor seven, got " .. Descent.depth(back))
            assert((Descent.floorBoard(back, 6) or {}).marker == "six",
                "with the board of the floor above, as they walked it")
            assert(restored.floors == nil, "a board was written onto the player -- the map book is retired")
        end,
    },
    {
        -- THE OTHER ENDING. Giving up is not being beaten: it drops the run, and the next descent opens
        -- at the top. Held here beside the wipe so the two cannot be collapsed into one answer by
        -- somebody reading either in isolation.
        name = "a run given up starts the next one at the top",
        fn = function()
            local player = Player.new()
            player.descentRun = runAt(player, 6)
            assert(Descent.depth(player.descentRun) == 6, "six floors down")

            player.descentRun = nil -- what states/game.lua's clearRun leaves behind
            local fresh = Descent.new(player, 99)
            assert(Descent.depth(fresh) == 1,
                "a descent begun after giving up starts at one, got " .. Descent.depth(fresh))
        end,
    },
    {
        -- THE RIFT RESETS: every run is a fresh rift. Seed.run folds in which run this is, so two runs
        -- on one save lay different ground, and the same run replays as itself (its seed rides the save).
        name = "every run lays new ground, and every run starts at floor one",
        fn = function()
            local player = Player.new()
            local first = Descent.new(player)
            local second = Descent.new(player)
            assert(first.seed ~= second.seed, "two runs on one save were dealt the same rift")
            assert(Descent.depth(first) == 1 and Descent.depth(second) == 1, "a run did not start at floor one")
            assert(next(second.floors or {}) == nil, "a new run carried boards in from the last")
            -- The first run's boards stay on the first run: nothing hangs them on the player.
            Descent.keepFloor(first, 1, { cols = 1, rows = 1, marker = "one" })
            assert(player.floors == nil, "a kept board leaked onto the player")
            assert(Descent.floorBoard(second, 1) == nil, "a new run found the last run's board")
        end,
    },
    {
        -- A FLOOR KEEPS ITS IDENTITY BY DEPTH. The circle, its biome and its guardian are dealt by depth on
        -- the authored order (Descent.sinOrder), and the elites off the lap seed and the depth
        -- (Descent.eliteSeed) -- none of it moves with the run's seed.
        name = "a floor's circle and its elite seed hold across runs",
        fn = function()
            local player = Player.new()
            local a, b = Descent.new(player), Descent.new(player)
            for floor = 1, Descent.FLOORS do
                local sa, sb = Descent.sinAt(a, floor), Descent.sinAt(b, floor)
                assert((sa and sa.id) == (sb and sb.id), "floor " .. floor .. " changed circle between runs")
                assert(Descent.biomeAt(a, floor) == Descent.biomeAt(b, floor), "floor " .. floor .. " changed ground")
            end
            assert(Descent.eliteSeed(player, 3) == Descent.eliteSeed(player, 3), "the elite seed is not stable")
            assert(Descent.eliteSeed(player, 3) ~= Descent.eliteSeed(player, 4), "two floors share an elite seed")
        end,
    },
    {
        -- A rest stop was the one thing on a floor with no downside, which made taking it an automatic
        -- yes. Its price was a percent once (an ambush that took the verb); it is a CERTAIN fight now,
        -- and the property that makes it a price is that it always comes and always comes NEXT.
        name = "lighting the fire fills the prowl meter, so the next step out of camp throws a fight",
        fn = function()
            for leg = 0, 12 do
                local run = { seed = 4242, leg = leg, prowl = 0 }
                Descent.lightFire(run)
                assert(not Descent.stepProwl({ seed = run.seed, leg = run.leg, prowl = run.prowl - 1 }),
                    "precondition: the meter is not already past its top on leg " .. leg)
                assert(Descent.stepProwl(run),
                    "leg " .. leg .. ": the fire was lit and the next step found nothing")
            end
            -- A meter already fuller than the fire would leave it is never wound BACK: camping must not
            -- buy a company quiet steps it had not walked.
            local run = { seed = 4242, leg = 0, prowl = 0 }
            run.prowl = Descent.prowlTarget(run) + 3
            local before = run.prowl
            Descent.lightFire(run)
            assert(run.prowl == before, "the fire emptied a meter it was supposed to fill")
            -- No run, no meter: an authored quest's camp keeps the guarantee it was authored with.
            Descent.lightFire(nil)
        end,
    },
    {
        -- A FLOOR RE-ENTERED WITHIN THE RUN KEEPS ITS CAMP SPENT. The camp was lit again every trip while
        -- boards outlived trips; a re-entry is always inside one run now, and camps must not compound in
        -- a run (Descent.FLOOR_RESTS). The old ambush's fight still goes back to being a camp.
        name = "a floor re-entered within the run keeps its camp spent, and the ambush's fight goes back to a camp",
        fn = function()
            local grid = {
                cols = 3, rows = 1,
                cells = { {
                    { x = 1, y = 1, cleared = true,
                      encounter = { kind = "rest", id = "encounter_rest", name = "A Moment's Rest" } },
                    -- WHAT THE OLD AMBUSH LEFT: a fight written over the camp, which the re-arm then woke
                    -- every trip -- the floor never had a camp again. A save carrying one gets it back.
                    { x = 2, y = 1, cleared = true,
                      encounter = { kind = "combat", name = "Ambushed at Camp", ambush = true } },
                    { x = 3, y = 1, cleared = true, encounter = { kind = "treasure", id = "chest" } },
                } },
            }
            local woken = Descent.rearmFloor(grid)
            local cells = grid.cells[1]
            assert(cells[1].encounter.kind == "rest" and cells[1].cleared,
                "a camp spent earlier this run was lit again by walking back onto the floor")
            assert(cells[2].encounter.kind == "rest" and not cells[2].cleared,
                "the ambush's fight was woken again instead of handing the camp back")
            assert(cells[3].cleared, "a spent cache came back")
            assert(woken == 0, "a camp was counted as a monster standing: " .. woken)
        end,
    },
    {
        -- THE PANEL QUOTES WHAT THE CAMP PAYS, so the forecast and the heal must be one number. Run the
        -- forecast, then the camp, and read the bars: any drift between the two is the panel lying.
        name = "the camp's forecast is the heal the camp then pays",
        fn = function()
            local Character = require("models.character")
            local p = Player.new()
            local a = Character.instantiate("character_alchemist")
            a.stats.health.current = 7
            p.roster = { a }
            local rows, any = Player.campForecast(p)
            assert(any, "a wounded company was told it had nothing to rest off")
            assert(#rows == 1 and rows[1].from == 7, "the forecast did not start where the bar stands")
            assert(a.stats.health.current == 7, "forecasting a camp healed somebody")
            Player.camp(p)
            assert(a.stats.health.current == rows[1].to,
                "forecast said " .. rows[1].to .. ", the camp paid " .. a.stats.health.current)

            -- WHOLE, nothing is on offer: a heal that moves no bar would light the fire for nothing.
            for _, stat in ipairs(Character.RESOURCE_STATS) do
                local r = a.stats[stat]
                if type(r) == "table" then r.current = r.max end
            end
            local _, anyLeft = Player.campForecast(p)
            assert(not anyLeft, "a whole company was offered a heal")
        end,
    },
    {
        -- THE BAG HAS A BOTTOM AGAIN, and it is the same reversal as the floor count: models/mule.lua's
        -- ceiling was deleted because "the wipe takes nothing now, so the ceiling was guarding a stake
        -- that no longer exists". The wipe takes the haul again, so the stake is back.
        --
        -- AND IT COUNTS THE BAG NOW, NOT THE DIFF. This case used to fill the STASH and assert that
        -- the ceiling saw it, because the ceiling was Player.atRisk and the stash was where a find
        -- landed. Both halves moved: a find lands in player.pack (Player.stow) and the ceiling counts
        -- that container's slots (Descent.carried). What the case is FOR is unchanged -- the shelf at
        -- home is unbounded and the bag is not -- so it is rewritten rather than deleted.
        name = "the bag counts what is in it, the shelf at home is unbounded, and town is not the bag",
        fn = function()
            local Item = require("models.item")
            local Character = require("models.character")

            local player = Player.new()
            player.roster = { Character.instantiate("character_knight") }
            -- A COMPANY THAT MARCHED IN RICH -- on the SHELF, well past the cap, and none of it in the
            -- bag. The town's stock has never been what the ceiling measures.
            for _ = 1, Descent.CARRY_MAX + 5 do
                Player.addToStash(player, Item.instantiate("weapon_iron_sword"))
            end
            local run = Descent.new(player, 7)
            run.entry = Save.snapshot(player)

            assert(Descent.carried(player) == 0,
                "the shelf at home is being counted against the bag")
            assert(Descent.carryRoom(player) == Descent.CARRY_MAX,
                "a company with an empty bag has the whole of it free")

            -- ...AND THE SHELF STAYS UNBOUNDED. The cap is on what they CARRY, which is why the stash
            -- can hold more than CARRY_MAX without anything being wrong.
            assert(#player.stash > Descent.CARRY_MAX,
                "the fixture did not actually exceed the cap; the next assertion proves nothing")

            -- PACKED, one at a time, until the bag is full. Straight into the pack rather than through
            -- Player.stow: what is being measured here is the container, not the routing (that is
            -- tests/pack_spec.lua's question).
            for _ = 1, Descent.CARRY_MAX do
                Player.addToPack(player, Item.instantiate("weapon_iron_sword"))
            end
            assert(Descent.carried(player) == Descent.CARRY_MAX,
                "packed " .. Descent.CARRY_MAX .. " and the bag reads " .. Descent.carried(player))
            assert(Descent.carryRoom(player) == 0, "the bag should be full")

            -- OVER THE LINE READS AS FULL rather than as owing slots -- a cap lowered between saves
            -- must not hand back a negative that a caller then adds to something.
            Player.addToPack(player, Item.instantiate("weapon_iron_sword"))
            assert(Descent.carryRoom(player) == 0, "an over-full bag reported negative room")

            -- AND THE DIFF SURVIVES AS ITS OWN QUESTION. Everything above was packed after the entry
            -- snapshot, so the trip has "found" all of it -- but the two numbers answer different
            -- questions and the stair must only ever see this one (Descent.tollFor).
            assert(Descent.found(player, run) > 0,
                "the haul diff stopped seeing what was added after the snapshot")
        end,
    },
    {
        -- A cap nobody can reach is not a cap, and one that binds on floor one is a different game.
        -- (2026-10-25) The STARTING bag is small on purpose -- ten, and the rest is bought -- so the
        -- promises moved to the bag gold can buy.
        name = "the bag starts small, and gold grows it to one worth filling and small enough to bite",
        fn = function()
            assert(Descent.CARRY_MAX < Descent.CARRY_CAP, "a starting bag with nothing left to buy")
            assert((Descent.CARRY_CAP - Descent.CARRY_MAX) % Descent.CARRY_STEP == 0,
                "the last step overshoots the cap and the bag stops between two sizes")
            assert(Descent.CARRY_CAP <= 40,
                "a bag this big (" .. Descent.CARRY_CAP .. ") is never reached, which is the mule's "
                .. "own complaint: a bet with no ceiling is not a bet")
            -- ...AND THE BOUGHT BAG HAS TO LEAVE ROOM FOR A TRIP ON TOP OF THE RATIONS (models/descent.lua's
            -- header: twenty of finding plus eight of supplies).
            assert(Descent.CARRY_CAP >= 20 + 8,
                "the biggest bag no longer holds a provisioned company plus four floors of finding")
        end,
    },
    {
        name = "a bag step costs twice the last, adds its slots, and stops at the cap",
        fn = function()
            local player = { gold = 0, roster = {}, pack = {} }
            assert(Descent.carryMax(player) == Descent.CARRY_MAX, "a new company's bag is not the base")
            assert(Descent.bagStepPrice(player) == Descent.CARRY_PRICE, "the first step is not the base price")
            local ok, why = Descent.buyBagStep(player)
            assert(not ok and why == "gold", "a step was sold to an empty purse")
            assert(Descent.carryMax(player) == Descent.CARRY_MAX, "a refused step still grew the bag")

            player.gold = 10 ^ 9
            local price, steps = Descent.CARRY_PRICE, 0
            while Descent.bagStepPrice(player) do
                assert(Descent.bagStepPrice(player) == price, "step " .. steps .. " is not double the last")
                local before = player.gold
                assert(Descent.buyBagStep(player), "an affordable step was refused")
                assert(before - player.gold == price, "the step charged something other than its price")
                steps, price = steps + 1, price * 2
                assert(Descent.carryMax(player) == Descent.CARRY_MAX + steps * Descent.CARRY_STEP,
                    "step " .. steps .. " did not add its slots")
            end
            assert(Descent.carryMax(player) == Descent.CARRY_CAP, "the bought bag stops short of the cap")
            local ok2, why2 = Descent.buyBagStep(player)
            assert(not ok2 and why2 == "full", "a step was sold past the cap")
        end,
    },
    {
        name = "the bag's steps ride a save",
        fn = function()
            local Save = require("models.save")
            local Player = require("models.player")
            local player = Player.new()
            player.gold = 1000
            assert(Descent.buyBagStep(player) and Descent.buyBagStep(player), "two steps refused")
            local back = Save.restore(Save.decode("return " .. Save.encode(Save.snapshot(player), 0)))
            assert(Descent.carryMax(back) == Descent.CARRY_MAX + 2 * Descent.CARRY_STEP,
                "the bag came back from the save at " .. Descent.carryMax(back))
        end,
    },
    {
        -- The ordinary fight is not seated on a tile at all: it is rolled as the company walks
        -- (Descent.PROWL_STEPS), which is Wizardry's own arrangement and the reason a level down there
        -- is never finished with you.
        name = "the prowl throws a fight on a bounded interval, and the same run replays it",
        fn = function()
            local run = Descent.new(Player.new(), 606)

            -- BOUNDED BOTH WAYS. Too short and a floor is a treadmill; too long and a company crosses
            -- one without ever being found, which is the safe-once-cleared floor this exists to end.
            local seen = {}
            for leg = 0, 59 do
                run.leg = leg
                local t = Descent.prowlTarget(run)
                assert(t >= Descent.PROWL_STEPS - Descent.PROWL_JITTER
                    and t <= Descent.PROWL_STEPS + Descent.PROWL_JITTER,
                    "leg " .. leg .. " runs " .. t .. " steps, outside the declared window")
                seen[t] = true
            end
            local distinct = 0
            for _ in pairs(seen) do distinct = distinct + 1 end
            -- NOT A METRONOME. A fixed interval is one the player counts on their fingers, and the
            -- readout stops being a warning and becomes a countdown.
            assert(distinct >= 4,
                "sixty legs ran only " .. distinct .. " distinct lengths -- the jitter is not jittering")

            -- SAME SEED, SAME WALK. A trip replayed off one save has to meet the same fights at the same
            -- spacing, or a bug report about one cannot be replayed.
            local twin = Descent.new(Player.new(), 606)
            twin.leg = 7
            run.leg = 7
            assert(Descent.prowlTarget(twin) == Descent.prowlTarget(run),
                "two runs on one seed disagree about the same leg; the roll is not off the seed")

            -- IT FIRES, and only once the meter is full.
            run.leg, run.prowl = 0, 0
            local fired, steps = false, 0
            for _ = 1, Descent.PROWL_STEPS + Descent.PROWL_JITTER do
                steps = steps + 1
                if Descent.stepProwl(run) then fired = true break end
            end
            assert(fired, "the company walked a full window and nothing found them")
            assert(steps >= Descent.PROWL_STEPS - Descent.PROWL_JITTER,
                "something found them after " .. steps .. " steps, inside the floor of the window")

            -- ...and the meter goes back to nothing, on a fresh leg.
            local before = run.leg or 0
            Descent.calmProwl(run)
            assert(run.prowl == 0, "the meter stayed full after a fight")
            assert(run.leg == before + 1, "the leg did not advance, so the next roll repeats this one")
        end,
    },
    {
        name = "what the prowl throws is an ordinary fight -- never an elite, never a place",
        fn = function()
            local run = Descent.new(Player.new(), 4242)
            local pool = {
                { kind = "combat", id = "wolves", name = "Wolves", weight = 3 },
                { kind = "combat", id = "rats", name = "Rats", weight = 3 },
                { kind = "combat", id = "shades", name = "Shades", weight = 3 },
                -- Everything the meter may not deal, weighted heavily enough that a pick which ignored
                -- kind would land on one almost every time.
                { kind = "elite", id = "ogre", name = "Ogre", weight = 40 },
                { kind = "treasure", id = "chest", name = "Chest", weight = 40 },
                { kind = "rest", id = "camp", name = "Camp", weight = 40 },
            }

            local ids = {}
            for leg = 0, 39 do
                run.leg = leg
                local enc = Descent.wander(run, pool)
                assert(enc, "the meter topped out and nothing was dealt")
                -- AN ELITE IS A THING YOU ARE MEANT TO SEE. One thrown by the meter would be the worst
                -- of both designs: a fight you can neither prepare for nor route around.
                assert(enc.kind == "combat",
                    "the prowl dealt a " .. tostring(enc.kind) .. "; only ordinary fights may be rolled")
                assert(enc.id == "wolves" or enc.id == "rats" or enc.id == "shades",
                    "the prowl dealt " .. tostring(enc.id) .. ", which is not an ordinary fight")
                -- Tagged, so everything downstream can tell a rolled fight from a seated one -- the
                -- flee offer reads it first.
                assert(enc.wandering, "a rolled fight is not marked as one")
                ids[enc.id] = true
            end

            local distinct = 0
            for _ in pairs(ids) do distinct = distinct + 1 end
            assert(distinct >= 2,
                "forty legs dealt " .. distinct .. " distinct fight(s) from a pool of three -- the "
                .. "weighted pick is stuck, which is what a per-leg walk over a linear hash does when "
                .. "consecutive salts come out correlated")

            -- A floor whose pool holds no ordinary fight deals nothing rather than reaching for an
            -- elite to fill the gap.
            assert(Descent.wander(run, { { kind = "elite", id = "ogre", weight = 1 } }) == nil,
                "a pool with no ordinary fight in it still dealt something")
        end,
    },
    {
        name = "the readout warms before the fight lands, and never counts down to it",
        fn = function()
            local run = Descent.new(Player.new(), 77)
            local earliest = Descent.PROWL_STEPS - Descent.PROWL_JITTER

            run.prowl = 0
            assert(Descent.prowlBand(run) == "calm", "a company that just fought is not calm")

            -- IT WARMS BEFORE IT CAN BITE. The gauge has to turn over PROWL_WARN steps before the
            -- earliest a fight can possibly land, or the shortest leg there is arrives on the same step
            -- the warning does -- which is a notification, not a warning.
            run.prowl = earliest - Descent.PROWL_WARN
            assert(Descent.prowlBand(run) == "close",
                "the gauge is still " .. Descent.prowlBand(run) .. " with " .. Descent.PROWL_WARN
                .. " steps to go before a fight can land; the shortest leg gets no warning at all")
            run.prowl = earliest - Descent.PROWL_WARN - 1
            assert(Descent.prowlBand(run) ~= "close",
                "the gauge tops out earlier than the window it is warning about")

            -- ...AND THEN IT SAYS NOTHING MORE, which is the half that keeps it a warning rather than a
            -- countdown. Every step from there to the far end of the window reads the same, so two
            -- things are true at once: something can find you from here on, and nothing on screen says
            -- when. A gauge that kept climbing would hand the player the exact step.
            for p = earliest - Descent.PROWL_WARN, Descent.PROWL_STEPS + Descent.PROWL_JITTER do
                run.prowl = p
                assert(Descent.prowlBand(run) == "close",
                    "the gauge reads " .. Descent.prowlBand(run) .. " at " .. p .. " steps -- inside "
                    .. "the window it must read the same at every step, or it is counting down")
            end

            -- AND THE WINDOW IS WIDE ENOUGH TO HIDE IN. One possible step is a countdown however it is
            -- banded.
            assert(2 * Descent.PROWL_JITTER + 1 >= 5,
                "a window of " .. (2 * Descent.PROWL_JITTER + 1) .. " steps is short enough to count")

            -- The whole window is actually used: legs land short of the base and long of it, so the
            -- jitter is sampling rather than walking a short cycle (Descent.prowlTarget hashes twice).
            local short, long = nil, nil
            for leg = 0, 59 do
                run.leg = leg
                local t = Descent.prowlTarget(run)
                if t == earliest then short = t end
                if t == Descent.PROWL_STEPS + Descent.PROWL_JITTER then long = t end
            end
            assert(short and long,
                "sixty legs never reached both ends of the window -- the roll is walking a cycle "
                .. "instead of sampling it")
        end,
    },
    {
        name = "the step clock rides in the save, so a reload does not hand back a quiet floor",
        fn = function()
            local player = Player.new()
            local run = Descent.new(player, 11)
            run.steps = 37
            run.prowl = 9
            run.leg = 4
            player.descentRun = run

            local back = Save.restore(Save.snapshot(player)).descentRun
            assert(back and back.steps == 37,
                "the step clock came back at " .. tostring(back and back.steps) ..
                " -- a player could reload to keep a cleared floor clear")
            -- THE METER IS THE WHOLE FEATURE, so it has to ride or the feature is optional. A player
            -- who can see the readout go red and knows a reload empties it will quit and Continue
            -- rather than fight, and the prowl becomes a tax on people who do not know that.
            assert(back.prowl == 9,
                "the prowl meter came back at " .. tostring(back.prowl) ..
                " -- a reload empties it, so every fight is dodgeable from the pause menu")
            -- ...and the LEG, or the next interval and the next monster are re-dealt identically after
            -- every load: the same fight, at the same spacing, forever.
            assert(back.leg == 4,
                "the leg came back at " .. tostring(back.leg) .. " -- the walk repeats itself on reload")
        end,
    },
    {
        name = "the prowl clock is slow enough to be a choice and fast enough to be felt",
        fn = function()
            -- Measured: a floor is ~91 places with a 23-step crossing (`. board-report`), so clearing
            -- one is somewhere near 70 steps of walking. This is the rate the ordinary fighting arrives
            -- at now that none of it is seated (Descent.PROWL_STEPS).
            assert(Descent.PROWL_STEPS >= 8,
                "at " .. Descent.PROWL_STEPS .. " steps a floor is a treadmill -- a company cannot cross "
                .. "a room without being found, and the flee roll becomes the whole game")
            assert(Descent.PROWL_STEPS <= 30,
                "at " .. Descent.PROWL_STEPS .. " steps a company can cross a whole floor without "
                .. "meeting anything, which is the safe-once-cleared floor this exists to end")
            -- THE JITTER MAY NOT EAT THE WINDOW. At jitter >= base the interval could roll to nothing
            -- and a fight would land on the tile the last one ended on.
            assert(Descent.PROWL_JITTER >= 1 and Descent.PROWL_JITTER < Descent.PROWL_STEPS / 2,
                "a jitter of " .. Descent.PROWL_JITTER .. " against a base of " .. Descent.PROWL_STEPS
                .. " is not a window, it is a coin flip")
        end,
    },
    {
        name = "a wanderer is swept off a kept board rather than woken on it",
        fn = function()
            -- THE MAP DRAWS THE FLOOR, NOT THE METER'S HISTORY. A rolled fight is written onto whatever
            -- tile the company happened to be standing on when the meter topped out (states/game.lua's
            -- onArrive), so it is not a place and must not outlive itself as one.
            --
            -- AND A LEFTOVER ONE DOES NOT MERELY LINGER -- the rule this pins would WAKE it, because it
            -- is an uncleared combat as far as the re-arm is concerned. That is permanent SEATED combat
            -- appearing on a floor whose whole design seats none (Descent.wander's header), one more
            -- plate per wanderer per trip, compounding for the life of the save.
            local grid = {
                cols = 4, rows = 1,
                cells = { {
                    { x = 1, y = 1, cleared = true,
                      encounter = { kind = "combat", id = "wolves", wandering = true } },
                    -- Not cleared: a wanderer the company quit on, or went down the stair to get away
                    -- from. Swept too -- coming back is answered by the meter dealing a fresh one where
                    -- they are standing, not by the old one waiting on the tile they left it on.
                    { x = 2, y = 1,
                      encounter = { kind = "combat", id = "rats", wandering = true } },
                    -- The seated half, untouched: this split is what the whole re-entry rests on.
                    { x = 3, y = 1, cleared = true, encounter = { kind = "combat", id = "seated" } },
                    { x = 4, y = 1, cleared = true, encounter = { kind = "treasure", id = "chest" } },
                } },
            }

            local woken = Descent.rearmFloor(grid)
            local cells = grid.cells[1]

            assert(cells[1].encounter == nil and cells[1].cleared == nil,
                "a beaten wanderer is still drawn on the tile it found you on")
            assert(cells[2].encounter == nil,
                "a wanderer the company walked away from is still sitting where it was dealt")
            assert(cells[3].encounter and not cells[3].cleared,
                "the floor's own seated fight did not come back on its feet")
            assert(cells[4].encounter and cells[4].cleared,
                "a place woke up -- the maze is permanent and only its monsters are not")
            assert(woken == 1, "rearmFloor reported " .. woken .. " monsters standing; only the seated "
                .. "fight is one, and counting swept residue would report a floor full of nothing")
        end,
    },
}
