-- THE RETURN TRIP: what a company comes back to after it is beaten.
--
-- A wipe does not end a descent. The bodies wake at the Gate, poorer and hurt, and the stair they walk
-- back down opens on the SAME FLOOR they fell on, laid out the way they left it -- with everything they
-- were carrying in a heap on the tile where it happened.
--
-- None of that was pinned anywhere, and it is the property the whole mode rests on. Everything the wipe
-- path does is destructive -- drop the pack, take the coin, wound the company, save the board -- so the
-- failure this file exists to catch is a well-meaning tidy-up on that path resetting the one field that
-- must not move. A run reset to floor one after a wipe is a nine-floor walk the player already made,
-- and nothing else in the game would say a word about it.
--
-- The contrast at the bottom is the deliberate half: GIVING UP does end a run, and the next one starts
-- at the top. Two endings, two answers, and this file holds them side by side so neither can be
-- "fixed" into the other by somebody reading only one.

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
        name = "the floor a company fell on is the floor its stair goes back to",
        fn = function()
            local player = Player.new()
            local run = runAt(player, 9)
            assert(Descent.depth(run) == 9, "the fixture stands on floor nine, got " .. Descent.depth(run))

            -- Everything the wipe path does to the run, in the order states/game.lua does it. None of
            -- it is allowed to move where the company is standing. The pack drop that used to lead
            -- this list is gone with the pile system (models/descent.lua) -- a wipe takes nothing.
            Descent.keepFloor(run, 9, { cols = 8, rows = 8, marker = "the board they died on" })

            assert(Descent.depth(run) == 9,
                "a wipe must not move the company off floor nine, got " .. Descent.depth(run))
            assert(run.cleared == 8,
                "and the floor that killed them is not credited as beaten, got " .. tostring(run.cleared))
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
        -- ...ACROSS A SAVE, because a wipe is exactly when a player quits. Board and depth have to
        -- survive together: either one coming back without the other is a return trip to the wrong
        -- place, or to the right place with the wrong ground under it.
        name = "depth and board survive the quit a wipe invites",
        fn = function()
            local player = Player.new()
            local run = runAt(player, 7)
            -- The map book is the COMPANY's now (Descent.keepFloor), so the two halves this case is
            -- about ride in different places: the depth is the run's, the board is the player's. That
            -- split is the point -- the run is thrown away at every exit and the board must not be.
            Descent.keepFloor(player, 7, { cols = 8, rows = 8, marker = "seven" })
            player.descentRun = run

            local restored = Save.restore(Save.snapshot(player))
            local back = restored.descentRun
            assert(back, "the run comes back at all")
            assert(Descent.depth(back) == 7, "on floor seven, got " .. Descent.depth(back))
            assert((Descent.floorBoard(restored, 7) or {}).marker == "seven",
                "with the board they walked")
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
        -- THE ONLY THING A WIPE TAKES. Everything else about a rout is deliberately free
        -- (docs/the-count.md): no gold, no wound, no mark, and the map book survives. What stays behind
        -- is this expedition's HAUL, on the tile it fell on -- and it stays rather than vanishing,
        -- which is what keeps a loss a retrieval problem instead of a confiscation.
        name = "a rout leaves what the trip FOUND on the floor, and nothing the company walked in with",
        fn = function()
            local Item = require("models.item")
            local Character = require("models.character")

            local player = Player.new()
            player.roster = { Character.instantiate("character_knight") }
            -- MARCHED IN WITH: one sword, in the stash. This must still be there afterwards.
            local brought = Item.instantiate("weapon_iron_sword")
            assert(brought, "fixture blueprint is gone -- retarget this case")
            Player.addToStash(player, brought)

            -- The company exactly as it walked in. This is the diff Player.atRisk measures against.
            local entry = Save.snapshot(player)

            -- ...AND FOUND DOWN THERE: a second copy of the same blueprint. Same id on purpose -- it is
            -- the case the entry allowance exists for, and a naive implementation drops both.
            local found = Item.instantiate("weapon_iron_sword")
            Player.addToStash(player, found)

            local board = { cols = 4, rows = 4, cells = {} }
            for y = 1, 4 do
                board.cells[y] = {}
                for x = 1, 4 do board.cells[y][x] = { x = x, y = y } end
            end
            Descent.keepFloor(player, 3, board)

            local haul = Player.takeAtRisk(player, entry)
            assert(#haul == 1, "one piece was found this trip, got " .. #haul)
            Descent.dropPack(player, 3, 2, 2, haul)

            -- WHAT THEY KEEP: the sword they brought, still in the stash.
            assert(#player.stash == 1, "the kit they marched down with was taken too")
            assert(player.stash[1].id == "weapon_iron_sword", "and it is the one they brought")

            -- WHAT IS LYING THERE: one pile, on the floor and tile they fell on.
            local packs = Descent.lostPacks(player)
            assert(#packs == 1, "the haul did not land on the floor, got " .. #packs .. " piles")
            assert(packs[1].floor == 3 and packs[1].x == 2 and packs[1].y == 2,
                "the pile is not on the tile they fell on")
            assert(packs[1].count == 1, "the pile holds " .. packs[1].count .. ", not the one piece found")

            -- AND IT SURVIVES THE SAVE, which is the whole point of hanging it on the kept board: the
            -- run is discarded at every exit and the pile must outlive it. Round-tripped through the
            -- real serializer, because a cell holding live instances would take the save down.
            local back = Save.restore(Save.decode("return " .. Save.encode(Save.snapshot(player), 0)))
            local afterPacks = Descent.lostPacks(back)
            assert(#afterPacks == 1, "the pile did not survive the save")
            assert(afterPacks[1].floor == 3, "and it came back on the wrong floor")

            -- PICKING IT UP hands the piece over and clears the marker, so a tile cannot pay twice.
            local cell = Descent.floorBoard(back, 3).cells[2][2]
            local taken = Descent.takePack(back, 3, cell)
            assert(taken and #taken == 1, "walking back onto the pile handed back nothing")
            assert(taken[1].id == "weapon_iron_sword", "and it handed back the wrong thing")
            assert(#Descent.lostPacks(back) == 0, "the pile is still lying there after being taken")
            assert(Descent.takePack(back, 3, cell) == nil, "the same tile paid out twice")
        end,
    },
    {
        -- A HUSK IS THE COMMON CASE now that most of what a floor pays is sealed
        -- (Spoils.SEALED_CHANCE), and it is the one thing an id and a level cannot rebuild. The deleted
        -- pile system rehydrated through Item.instantiate and would have flattened every one of them
        -- into a plain piece -- silently, with no crash and nothing red.
        name = "a sealed piece comes out of the pile still sealed",
        fn = function()
            local Identify = require("models.identify")
            local player = Player.new()

            local husk = Identify.sealed("weapon_iron_sword", 4)
            assert(husk and (husk.unidentified or 0) > 0, "fixture husk is not sealed -- retarget this")

            local board = { cols = 2, rows = 2, cells = { {}, {} } }
            for y = 1, 2 do for x = 1, 2 do board.cells[y][x] = { x = x, y = y } end end
            Descent.keepFloor(player, 1, board)
            Descent.dropPack(player, 1, 1, 1, { husk })

            local back = Save.restore(Save.decode("return " .. Save.encode(Save.snapshot(player), 0)))
            local taken = Descent.takePack(back, 1, Descent.floorBoard(back, 1).cells[1][1])
            assert(taken and #taken == 1, "the husk did not come back")
            assert((taken[1].unidentified or 0) > 0,
                "the husk came back IDENTIFIED -- the pile rehydrated it through the wrong path, and "
                .. "the player has been handed a free naming they did not pay the Touchstone for")
        end,
    },
    {
        -- Two deaths on one tile must not delete the first haul: that is billing one failure twice, and
        -- it is the exact shape docs/the-count.md's law exists to refuse.
        name = "a second rout on the same tile adds to the pile rather than replacing it",
        fn = function()
            local Item = require("models.item")
            local player = Player.new()
            local board = { cols = 2, rows = 2, cells = { {}, {} } }
            for y = 1, 2 do for x = 1, 2 do board.cells[y][x] = { x = x, y = y } end end
            Descent.keepFloor(player, 2, board)

            Descent.dropPack(player, 2, 1, 1, { Item.instantiate("weapon_iron_sword") })
            Descent.dropPack(player, 2, 1, 1, { Item.instantiate("weapon_iron_sword") })

            local packs = Descent.lostPacks(player)
            assert(#packs == 1, "two deaths on one tile left " .. #packs .. " piles, not one")
            assert(packs[1].count == 2, "the second rout overwrote the first haul instead of adding to it")
        end,
    },
    {
        -- A rest stop was the one thing on a floor with no downside, which made taking it an automatic
        -- yes and made "spend the stop now or carry the damage deeper" not a decision at all.
        name = "camping is risky, and the risk climbs with depth but never past its ceiling",
        fn = function()
            local shallow = Descent.ambushChance(1)
            local deep = Descent.ambushChance(Descent.FLOORS)
            assert(shallow == Descent.AMBUSH_BASE,
                "floor one camps at the base rate, got " .. shallow)
            assert(deep > shallow, "camping deep must be riskier than camping at the mouth")

            -- CAPPED WELL UNDER A COIN FLIP. Above 50% the honest advice becomes "never camp", and a
            -- stop nobody takes is a stop that may as well not be dealt onto the floor.
            assert(deep <= Descent.AMBUSH_MAX, "the bottom floor camps past the ceiling: " .. deep)
            assert(Descent.AMBUSH_MAX < 50,
                "the ambush ceiling is at or past a coin flip (" .. Descent.AMBUSH_MAX ..
                "%), which makes never camping the correct play")

            -- MONOTONIC, so a player who learns "deeper is worse" is never wrong on some middle floor.
            local prev = -1
            for f = 1, Descent.FLOORS do
                local c = Descent.ambushChance(f)
                assert(c >= prev, "the camp risk dips at floor " .. f)
                prev = c
            end

            -- AND IT IS A REAL NUMBER AT EVERY DEPTH -- a zero anywhere would be a floor where the
            -- panel quotes nothing and the stop silently goes back to being free.
            assert(Descent.ambushChance(1) > 0, "camping at the mouth reads as risk-free")
        end,
    },
    {
        -- THE BAG HAS A BOTTOM AGAIN, and it is the same reversal as the floor count: models/mule.lua's
        -- ceiling was deleted because "the wipe takes nothing now, so the ceiling was guarding a stake
        -- that no longer exists". The wipe takes the haul again, so the stake is back.
        name = "the bag caps the trip's finds and never the kit that walked in, and town is unbounded",
        fn = function()
            local Item = require("models.item")
            local Character = require("models.character")

            local player = Player.new()
            player.roster = { Character.instantiate("character_knight") }
            -- A COMPANY THAT MARCHED IN RICH. Well past the cap, and none of it is "carried".
            for _ = 1, Descent.CARRY_MAX + 5 do
                Player.addToStash(player, Item.instantiate("weapon_iron_sword"))
            end
            local run = Descent.new(player, 7)
            run.entry = Save.snapshot(player)

            assert(Descent.carried(player, run) == 0,
                "the kit the company walked in with is being counted against the bag")
            assert(Descent.carryRoom(player, run) == Descent.CARRY_MAX,
                "a company that has found nothing has the whole bag free")

            -- ...AND THE SAME SHELF AT HOME IS UNBOUNDED. The cap is on the HAUL, which is why the
            -- stash can hold more than CARRY_MAX without anything being wrong.
            assert(#player.stash > Descent.CARRY_MAX,
                "the fixture did not actually exceed the cap; the next assertion proves nothing")

            -- FOUND, one at a time, until the bag is full.
            for _ = 1, Descent.CARRY_MAX do
                Player.addToStash(player, Item.instantiate("weapon_iron_sword"))
            end
            assert(Descent.carried(player, run) == Descent.CARRY_MAX,
                "found " .. Descent.CARRY_MAX .. " and the bag reads " ..
                Descent.carried(player, run))
            assert(Descent.carryRoom(player, run) == 0, "the bag should be full")

            -- OVER THE LINE READS AS FULL rather than as owing slots -- a cap lowered between saves
            -- must not hand back a negative that a caller then adds to something.
            Player.addToStash(player, Item.instantiate("weapon_iron_sword"))
            assert(Descent.carryRoom(player, run) == 0, "an over-full bag reported negative room")
        end,
    },
    {
        -- A cap nobody can reach is not a cap, and one that binds on floor one is a different game.
        name = "the bag is big enough to be worth filling and small enough to bite",
        fn = function()
            assert(Descent.CARRY_MAX >= 12,
                "a bag this small (" .. Descent.CARRY_MAX .. ") binds before a company has had a trip")
            assert(Descent.CARRY_MAX <= 40,
                "a bag this big (" .. Descent.CARRY_MAX .. ") is never reached, which is the mule's "
                .. "own complaint: a bet with no ceiling is not a bet")
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
}
