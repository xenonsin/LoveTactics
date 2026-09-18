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
        -- Clearing a floor used to make it safe for good while you stood on it, so the back half of
        -- every floor was a walk -- and re-treading to close a level gap paid nothing on ground you had
        -- already beaten. Wizardry's answer is that the level is never finished with you.
        name = "a fight the company put down gets back up, away from them, and replays from the seed",
        fn = function()
            local player = Player.new()
            local run = Descent.new(player, 606)
            run.steps = 0

            -- A floor with four cleared fights spread to the far corner, and the company at (1,1).
            local function board()
                local g = { cols = 9, rows = 9, cells = {} }
                for y = 1, 9 do
                    g.cells[y] = {}
                    for x = 1, 9 do g.cells[y][x] = { x = x, y = y } end
                end
                for _, p in ipairs({ { 8, 8 }, { 9, 7 }, { 7, 9 }, { 8, 6 } }) do
                    local c = g.cells[p[2]][p[1]]
                    c.encounter = { kind = "combat" }
                    c.cleared = true
                end
                return g
            end

            local g = board()
            local woke = Descent.wakeOne(run, g, 1, 1)
            assert(woke, "nothing woke on a floor full of cleared fights")
            assert(not woke.cleared, "the woken cell is still marked cleared")
            assert(woke.encounter and woke.encounter.kind == "combat", "something that is not a fight woke")

            -- SAME SEED, SAME WANDERER. A floor walked twice off one save has to wake the same fight in
            -- the same place, or a bug report about one cannot be replayed.
            local g2 = board()
            local again = Descent.wakeOne(run, g2, 1, 1)
            assert(again and again.x == woke.x and again.y == woke.y,
                "the same run and step woke a different cell; the roll is not off the seed")

            -- NEVER ON TOP OF THE COMPANY. A wanderer has to read as something that walked back into a
            -- room behind you, not as the floor spawning a fight on your head.
            local near = board()
            assert(Descent.wakeOne(run, near, 8, 8) == nil,
                "a fight woke inside RESPAWN_MIN_DIST of the company")

            -- ONLY WHAT LIVES ON A FLOOR. A spent cache is a place, not an inhabitant, and a floor that
            -- regrew its chests would be a faucet.
            local shop = { cols = 9, rows = 9, cells = {} }
            for y = 1, 9 do
                shop.cells[y] = {}
                for x = 1, 9 do shop.cells[y][x] = { x = x, y = y } end
            end
            shop.cells[8][8].encounter = { kind = "treasure" }
            shop.cells[8][8].cleared = true
            assert(Descent.wakeOne(run, shop, 1, 1) == nil, "a spent chest came back")
        end,
    },
    {
        name = "the step clock rides in the save, so a reload does not hand back a quiet floor",
        fn = function()
            local player = Player.new()
            local run = Descent.new(player, 11)
            run.steps = 37
            player.descentRun = run

            local back = Save.restore(Save.snapshot(player)).descentRun
            assert(back and back.steps == 37,
                "the step clock came back at " .. tostring(back and back.steps) ..
                " -- a player could reload to keep a cleared floor clear")
        end,
    },
    {
        name = "the wander clock is slow enough to be a choice and fast enough to be felt",
        fn = function()
            -- Measured: a floor is ~91 places with a 23-step crossing (`. board-report`). At this rate a
            -- company crossing one meets about two, and pacing a cleared floor to farm earns roughly one
            -- fight per crossing -- a time cost rather than a faucet.
            assert(Descent.RESPAWN_STEPS >= 6,
                "at " .. Descent.RESPAWN_STEPS .. " steps a cleared floor is a treadmill")
            assert(Descent.RESPAWN_STEPS <= 30,
                "at " .. Descent.RESPAWN_STEPS .. " steps a company can cross a whole floor without "
                .. "meeting one, which is the safe-once-cleared floor this exists to end")
            assert(Descent.RESPAWN_MIN_DIST >= 2,
                "a wanderer this close spawns on the company's head")
        end,
    },
}
