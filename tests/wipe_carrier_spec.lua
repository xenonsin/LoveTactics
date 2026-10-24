-- WHAT A WIPE COSTS (the author, 2026-10-23): a fall is a fall, what killed you carries your haul, and
-- hired bodies stay down.
--
--   * every body knocked out is injured, through the seam a rout uses (states/game.lua's wipe branch);
--   * the trip's haul goes to a CARRIER -- the cast that beat them, seated on the fall tile as an elite
--     (Descent.seatCarrier) -- which stands until killed, grows a level per further wipe on its floor,
--     and hands the haul back whole (sealed stays sealed) when it dies (Descent.takeCarrier);
--   * a hire in the company is stranded with it (Descent.strand): out of the Gate's pool, home again
--     when it dies, gone after Descent.STRAND_TRIPS trips (Descent.expireStranded).
--
-- The model halves are driven directly; the wipe branch itself lives in a state file no headless case
-- can play, so its order is read off the source, the way tests/rout_spec.lua reads the rout's.

local Descent = require("models.descent")
local Player = require("models.player")
local Save = require("models.save")
local Item = require("models.item")
local Character = require("models.character")
local Hire = require("models.hire")
local Encounter = require("models.encounter")
local EncounterBattle = require("models.encounter_battle")

-- An open w x h floor of places, the door at 1,1, kept for `floor`.
local function keptBoard(player, floor, w, h)
    local board = { cols = w, rows = h, cells = {}, start = { x = 1, y = 1 } }
    for y = 1, h do
        board.cells[y] = {}
        for x = 1, w do board.cells[y][x] = { x = x, y = y, tile = "path" } end
    end
    Descent.keepFloor(player, floor, board)
    return board
end

-- The wipe branch of states/game.lua's onLoss, CR-stripped (the tree is CRLF on Windows).
local function wipeBranch()
    local src = assert(love.filesystem.read("states/game.lua"), "cannot read states/game.lua")
    src = src:gsub("\r", "")
    local from = src:find("Descent.countBy(game.player, Descent.COUNT_WIPE)", 1, true)
    local to = src:find("game.player.pendingRout = floor", 1, true)
    assert(from and to and from < to, "the wipe branch is not where it was -- re-anchor this case")
    return src:sub(from, to)
end

local HIRE_ID = Hire.idOf("knight", "dwarf", 123456)

-- A company of two: the named cast's Rowan and one hire, both on the roster.
local function company()
    local player = Player.new()
    local rowan = Character.instantiate("character_rowan")
    local hire = Character.instantiate(HIRE_ID)
    assert(rowan and hire, "fixture bodies are gone -- retarget this case")
    player.roster = { rowan, hire }
    return player, rowan, hire
end

local function roundTrip(player)
    return Save.restore(Save.decode("return " .. Save.encode(Save.snapshot(player), 0)))
end

return {
    {
        name = "a wipe injures every body that fell, through the rout's seam, before the fight is let go",
        fn = function()
            local branch = wipeBranch()
            local hurt = branch:find("game:inflictInjuries()", 1, true)
            assert(hurt, "the wipe deals no injuries -- a fall is a fall, whatever the result")
            local over = branch:find("game.endFight()", 1, true)
            assert(over and hurt < over,
                "the wipe injures after the fight is let go, when the battle's list of who fell is stale")
            -- ...and a wipe's list of who fell is the whole company: battle.lose writes every fallen
            -- body (Combat.fallenParty), so one call charges each of them, exactly as the rout does.
            local player, rowan, hire = company()
            local Injury = require("models.injury")
            local dealt = Injury.inflict(player, { rowan, hire })
            assert(#dealt == 2, "two bodies fell and " .. #dealt .. " were injured")
        end,
    },
    {
        name = "the wipe branch seats the carrier after the board is banked, and strands its hires",
        fn = function()
            local branch = wipeBranch()
            local kept = branch:find("Descent.keepFloor(", 1, true)
            local seat = branch:find("Descent.seatCarrier(", 1, true)
            assert(kept and seat and kept < seat,
                "the carrier is written before the board it stands on is in the book")
            assert(branch:find("isHire", 1, true), "the wipe no longer tells its hires apart from the cast")
            assert(not branch:find("Descent.dropPack", 1, true), "the unguarded pile is back")
        end,
    },
    {
        name = "the carrier stands on the fall tile as an elite of the cast that won, holding the haul",
        fn = function()
            local player = company()
            local board = keptBoard(player, 4, 5, 5)
            local carrier = Descent.seatCarrier(player, 4, 3, 2, {
                items = { Item.instantiate("weapon_iron_sword") },
                composition = { "character_knight", "character_knight" },
                name = "The Thing", tier = 3,
            })
            assert(carrier and board.cells[2][3].encounter == carrier, "the carrier is not on the fall tile")
            assert(carrier.kind == "elite" and Descent.isCarrier(carrier), "the carrier is not an elite")
            assert(carrier.id == nil, "a carrier keeps a blueprint id, and with it the blueprint's objective")
            assert(#carrier.composition == 2 and carrier.enemyCap == 2, "the cast that won is not what stands")
            assert(carrier.levelBonus == 0, "a fresh carrier stands above the floor's own level")
            assert(carrier.count == 1 and #carrier.items == 1, "the carrier does not hold the haul")
            assert(not board.cells[2][3].cleared, "the carrier was seated already beaten")

            -- WHAT THE BOARD SEES: the pack's plate, a fight that opens, walk-off-able on its cast, and a
            -- plain kill-all of exactly that cast.
            assert(Encounter.markerKind(carrier) == "pack", "the carrier does not wear the pack's plate")
            assert(Encounter.opensBattle(carrier), "walking onto the carrier opens no fight")
            assert(EncounterBattle.cellEligible({ encounter = carrier }), "the carrier cannot be rated/walked off")
            local spec = EncounterBattle.spec({ encounter = carrier }, {}, 1)
            assert(spec.composition == carrier.composition and spec.objective == nil and spec.allies == nil,
                "the carrier is not fought as a plain kill-all of its own cast")

            local packs = Descent.lostPacks(player)
            assert(#packs == 1 and packs[1].carrier and packs[1].floor == 4 and packs[1].count == 1,
                "the Gate's readout does not see the carrier")
        end,
    },
    {
        name = "a carrier is never written over a place: off the stair, onto the nearest open ground",
        fn = function()
            local player = company()
            local board = keptBoard(player, 2, 4, 1)
            board.cells[1][3].encounter = { kind = "stair", name = "The Way Down" }
            board.cells[1][4].cache = true
            local carrier = Descent.seatCarrier(player, 2, 3, 1, {
                items = { Item.instantiate("weapon_iron_sword") }, composition = { "character_knight" } })
            assert(board.cells[1][3].encounter.kind == "stair", "the carrier was written over the way down")
            assert(board.cells[1][2].encounter == carrier,
                "the carrier is not on the nearest open place (not the cache, not the door)")
        end,
    },
    {
        name = "a carrier of nothing is not seated",
        fn = function()
            local player = company()
            keptBoard(player, 3, 3, 3)
            assert(Descent.seatCarrier(player, 3, 2, 2, { items = {}, composition = { "character_knight" } })
                == nil, "a carrier holding no haul and no hire was seated")
            assert(#Descent.lostPacks(player) == 0, "an empty carrier reads at the Gate")
        end,
    },
    {
        name = "the carrier stands: rearm never wakes or moves it, the elite reseat leaves it, a dead one goes",
        fn = function()
            local Overworld = require("models.overworld")
            local player = company()
            keptBoard(player, 5, 7, 7)
            local board = Descent.floorBoard(player, 5)
            board.tilesetId = "forest"
            board.cells[7][7].encounter = { kind = "elite", id = "encounter_a", tier = 3 }
            Descent.seatCarrier(player, 5, 6, 6, { items = { Item.instantiate("weapon_iron_sword") },
                composition = { "character_knight" } })

            local grid = Overworld.fromSnapshot(board)
            Descent.rearmFloor(grid)
            local pool = { { kind = "elite", id = "encounter_b", name = "B", weight = 1 } }
            grid:reseatElites(pool, 77)
            local c = grid.cells[6][6]
            assert(Descent.isCarrier(c.encounter) and not c.cleared,
                "the carrier was moved or woken by the floor's re-arming")

            -- BEATEN BUT NEVER PAID OUT -- the win marks the cell cleared before the summary's Continue
            -- hands the haul over, and a quit can land between the two. It stands up again holding it.
            c.cleared = true
            Descent.rearmFloor(grid)
            assert(Descent.isCarrier(c.encounter) and not c.cleared and c.encounter.count == 1,
                "a carrier beaten but never paid out was deleted with the haul still on it")

            -- Killed: the haul comes out (the win has cleared the cell first, as it does in play), the
            -- tile is spent, and the next re-arm lifts it off.
            c.cleared = true
            local taken = Descent.takeCarrier(player, 5, c)
            assert(taken and #taken == 1 and c.cleared, "killing the carrier did not hand the haul back")
            Descent.rearmFloor(grid)
            assert(c.encounter == nil, "a dead carrier came back with the floor's monsters")
        end,
    },
    {
        name = "a second wipe on the floor merges into the carrier and raises it one level",
        fn = function()
            local player, _, hire = company()
            keptBoard(player, 6, 4, 4)
            player.tripsCounted = 2
            Descent.seatCarrier(player, 6, 1, 2, { items = { Item.instantiate("weapon_iron_sword") },
                composition = { "character_knight" }, hires = { hire.id } })
            player.tripsCounted = 3
            local carrier, merged = Descent.seatCarrier(player, 6, 4, 4, {
                items = { Item.instantiate("weapon_iron_sword"), Item.instantiate("weapon_iron_sword") },
                composition = { "character_rowan" }, hires = { hire.id } })
            assert(merged, "the second wipe seated a second carrier")
            assert(carrier.count == 3, "the hauls did not merge: holds " .. carrier.count)
            assert(carrier.levelBonus == 1, "the carrier did not rise a level")
            assert(carrier.composition[1] == "character_knight", "the second wipe re-cast the carrier")
            assert(Descent.fightLevel(10, carrier) == 11, "the raised level does not reach the fight")
            assert(Descent.fightLevel(nil, carrier) == nil, "a fight with no clock of its own was given one")
            assert(Descent.strandedOf(player, hire.id).trip == 2,
                "a second wipe restarted a stranded hire's clock")
            assert(#Descent.lostPacks(player) == 1, "one floor reads as two carriers")
        end,
    },
    {
        name = "a hire is stranded with the carrier, out of the Gate's pool, and back when it dies",
        fn = function()
            local player, rowan, hire = company()
            keptBoard(player, 3, 3, 3)
            Descent.seatCarrier(player, 3, 2, 2, { items = {}, composition = { "character_knight" },
                hires = { hire.id, rowan.id } })
            assert(Descent.strandedOf(player, hire.id), "the hire came home with the named cast")
            assert(not Descent.strandedOf(player, rowan.id), "a named body was stranded")
            assert(#Descent.lostPacks(player) == 1 and Descent.lostPacks(player)[1].hires == 1,
                "a carrier holding only a hire does not read at the Gate")

            local run = { party = { rowan.id, hire.id } }
            local going = Descent.party(run, player)
            assert(#going == 1 and going[1].id == rowan.id, "a stranded hire can still walk down the stair")

            local _, cell = Descent.carrierOn(player, 3)
            local _, freed = Descent.takeCarrier(player, 3, cell)
            assert(freed and #freed == 1 and freed[1] == hire, "killing the carrier did not free the hire")
            assert(not Descent.strandedOf(player, hire.id), "the hire is still marked stranded")
            assert(#Descent.party(run, player) == 2, "the freed hire still cannot be picked")
        end,
    },
    {
        name = "a hire nobody fetches within three trips is gone, and their gear comes home",
        fn = function()
            local player, rowan, hire = company()
            keptBoard(player, 8, 3, 3)
            player.tripsCounted = 5
            local sword = Item.instantiate("weapon_iron_sword")
            Character.addItem(hire, sword)
            local stash = #(player.stash or {})
            Descent.seatCarrier(player, 8, 2, 2, { items = {}, composition = { "character_knight" },
                hires = { hire.id } })

            -- The wipe that stranded them is itself a counted trip (5 -> 6); three more follow it.
            player.tripsCounted = 8
            assert(#Descent.expireStranded(player) == 0, "a hire was given up after two trips")
            assert(#player.roster == 2, "the roster shrank early")

            player.tripsCounted = 9
            local gone = Descent.expireStranded(player)
            assert(#gone == 1 and gone[1].floor == 8 and gone[1].name == hire.name,
                "the third trip did not let the hire go, or the notice names the wrong body")
            assert(#player.roster == 1 and player.roster[1] == rowan, "the hire is still on the roster")
            assert(not Descent.strandedOf(player, hire.id), "a gone hire is still listed as stranded")
            assert(#(player.stash or {}) > stash, "the company's gear went with the hire")
            assert(Descent.strandClock(player) == Player.tripsHome(player),
                "the strand clock no longer reads the one trip count")
        end,
    },
    {
        name = "the carrier and its stranded hires survive the save",
        fn = function()
            local Identify = require("models.identify")
            local player, _, hire = company()
            keptBoard(player, 9, 3, 3)
            player.tripsCounted = 4
            local husk = Identify.sealed("weapon_iron_sword", 4)
            Descent.seatCarrier(player, 9, 2, 3, { items = { husk }, composition = { "character_knight" },
                name = "The Thing", hires = { hire.id } })
            Descent.seatCarrier(player, 9, 1, 1, { items = {}, composition = {} }) -- a second wipe: +1

            local back = roundTrip(player)
            local carrier, cell = Descent.carrierOn(back, 9)
            assert(carrier and cell, "the carrier did not survive the save")
            assert(carrier.levelBonus == 1 and carrier.name == "The Thing" and carrier.count == 1,
                "the carrier came back changed")
            assert(carrier.composition and carrier.composition[1] == "character_knight",
                "the carrier's cast did not survive the save")
            local s = Descent.strandedOf(back, hire.id)
            assert(s and s.floor == 9 and s.trip == 4, "the stranded hire did not survive the save")
            local onRoster = false
            for _, c in ipairs(back.roster) do onRoster = onRoster or c.id == hire.id end
            assert(onRoster, "the stranded hire fell off the roster in the save")

            local taken, freed = Descent.takeCarrier(back, 9, cell)
            assert(taken and #taken == 1 and (taken[1].unidentified or 0) > 0,
                "the husk came back identified after the save")
            assert(#freed == 1, "the restored hire was not freed by the kill")
            assert(back.stranded == nil, "the stranded ledger outlived its last body")
        end,
    },
}
