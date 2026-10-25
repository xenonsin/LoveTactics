-- WHAT A WIPE COSTS (2026-10-24): the haul is lost, the hires who fell are dead, the named cast comes
-- home injured.
--
--   * every body knocked out is injured, through the seam a rout uses (states/game.lua's wipe branch);
--   * the trip's finds (Player.takeAtRisk -- the diff against the company as it walked in) are gone:
--     the rift resets every run, so there is no floor for them to wait on (Descent.wipe);
--   * every hire in the expedition leaves the roster for good, and the company's gear on them goes
--     back to the stash (Hire.dismiss); a hire left on the bench is untouched.
--
-- It replaced tests/wipe_carrier_spec.lua, which held the carrier and the stranded hires -- both retired
-- with the persistent rift. The model half is driven directly; the wipe branch itself lives in a state
-- file no headless case can play, so its order is read off the source.

local Descent = require("models.descent")
local Player = require("models.player")
local Save = require("models.save")
local Item = require("models.item")
local Character = require("models.character")
local Hire = require("models.hire")

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
local BENCH_ID = Hire.idOf("knight", "human", 654321)

-- A company of three: Rowan and a hire walk down, a second hire stays on the bench.
local function company()
    local player = Player.new()
    local rowan = Character.instantiate("character_rowan")
    local hire = Character.instantiate(HIRE_ID)
    local bench = Character.instantiate(BENCH_ID)
    assert(rowan and hire and bench, "fixture bodies are gone -- retarget this case")
    player.roster = { rowan, hire, bench }
    local run = Descent.new(player, 4242)
    Descent.setParty(run, { rowan.id, hire.id })
    return player, run, rowan, hire, bench
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
        end,
    },
    {
        name = "the wipe branch loses the haul and buries the hires through Descent.wipe, then closes the run",
        fn = function()
            local branch = wipeBranch()
            local wipe = branch:find("Descent.wipe(game.player, game.descent)", 1, true)
            assert(wipe, "the wipe branch no longer charges the haul and the hires (Descent.wipe)")
            assert(branch:find("game:inflictInjuries()", 1, true) < wipe,
                "the hires are let go before the fall is charged, so the injuries miss them")
            local closed = branch:find("descentRun = nil", 1, true)
            assert(closed and wipe < closed, "the run is let go before the wipe reads its party")
            assert(branch:find("homecoming(game.player, game.descent, true)", 1, true),
                "a wipe no longer counts as a trip")
            assert(branch:find("Relic.endTrip(", 1, true), "a wipe keeps the trip's relics")
            -- ...and nothing of the retired carrier is left in it.
            for _, gone in ipairs({ "seatCarrier", "keepFloor", "strand", "dropPack" }) do
                assert(not branch:find(gone, 1, true), "the wipe branch still calls " .. gone)
            end
        end,
    },
    {
        name = "a wipe loses what the trip found and nothing the company walked in with",
        fn = function()
            local player, run, rowan = company()
            Descent.setParty(run, { rowan.id }) -- no hire down there, so the stash is the haul's alone
            local brought = Item.instantiate("weapon_iron_sword")
            assert(brought, "fixture blueprint is gone -- retarget this case")
            Player.addToStash(player, brought)
            run.entry = Save.snapshot(player)

            -- Found down there: a second copy of the same blueprint (the case the entry allowance is for).
            Player.addToStash(player, Item.instantiate("weapon_iron_sword"))
            local gold = player.gold

            local out = Descent.wipe(player, run)
            assert(out.lost == 1, "one piece was found this trip and " .. out.lost .. " were lost")
            assert(#player.stash == 1 and player.stash[1].id == "weapon_iron_sword",
                "the sword they brought was taken with the haul")
            assert(player.gold == gold and out.gold == 0, "a wipe took gold the company walked in with")
        end,
    },
    {
        name = "a wipe loses the gold found this run and never the gold the company walked in with",
        fn = function()
            local player, run, rowan = company()
            Descent.setParty(run, { rowan.id })
            player.gold = 120 -- what they walked in with: the opening purse, topped up at the Gate
            run.entry = Save.snapshot(player)
            Player.addGold(player, 340) -- earned down there
            local out = Descent.wipe(player, run)
            assert(out.gold == 340, "the wipe took " .. tostring(out.gold) .. " of the 340 gold found")
            assert(player.gold == 120, "the wipe left " .. player.gold .. " where 120 was walked in with")

            -- A company that spent below what it brought loses nothing more.
            player, run, rowan = company()
            Descent.setParty(run, { rowan.id })
            player.gold = 120
            run.entry = Save.snapshot(player)
            Player.spendGold(player, 50)
            Player.addGold(player, 30)
            out = Descent.wipe(player, run)
            assert(out.gold == 0 and player.gold == 100, "a wipe reached below the gold walked in with")

            -- No entry snapshot, nothing at stake.
            assert(Descent.goldAtRisk(player, nil) == 0, "gold is at risk with no entry snapshot")
        end,
    },
    {
        name = "climbing out keeps the gold: only the wipe branch charges it",
        fn = function()
            local src = assert(love.filesystem.read("models/descent.lua"), "cannot read models/descent.lua")
            src = src:gsub("\r", "")
            local n = 0
            for _ in src:gmatch("Descent%.goldAtRisk%(") do n = n + 1 end
            -- the definition, and the one call inside Descent.wipe
            assert(n == 2, "Descent.goldAtRisk is called " .. (n - 1) .. " times in descent.lua; only the wipe may")
            local branch = wipeBranch()
            assert(branch:find("pendingGoldLost", 1, true), "the wipe branch no longer tells the city the gold lost")
        end,
    },
    {
        name = "every hire in the expedition dies on a wipe; the bench and the named cast do not",
        fn = function()
            local player, run, rowan, hire, bench = company()
            local sword = Item.instantiate("weapon_iron_sword")
            Character.addItem(hire, sword)
            run.entry = Save.snapshot(player)
            local stash = #(player.stash or {})

            local out = Descent.wipe(player, run)
            assert(#out.dead == 1 and out.dead[1] == hire.name, "the notice names the wrong dead")
            local ids = {}
            for _, c in ipairs(player.roster) do ids[c.id] = true end
            assert(not ids[hire.id], "the hire who fell is still on the roster")
            assert(ids[rowan.id], "the named cast was taken off the roster")
            assert(ids[bench.id], "a hire who stayed on the bench died with the expedition")
            -- THE KIND HALF: the company's gear on the body comes home to the stash.
            assert(#(player.stash or {}) > stash, "the dead hire's gear did not come back to the stash")
        end,
    },
    {
        name = "an old save's map book and stranded hires load and are dropped",
        fn = function()
            local player, _, _, hire = company()
            local snap = Save.snapshot(player)
            snap.floors = { ["3"] = { cols = 1, rows = 1, cells = { { { x = 1, y = 1 } } } } }
            snap.stranded = { [hire.id] = { floor = 3, trip = 1 } }
            local back = Save.restore(Save.decode("return " .. Save.encode(snap, 0)))
            assert(back, "an old save with a map book no longer loads")
            assert(back.floors == nil, "the retired map book was read back onto the player")
            assert(back.stranded == nil, "the retired stranded ledger was read back onto the player")
            local found = false
            for _, c in ipairs(Descent.party(Descent.new(back, 1), back)) do found = found or c.id == hire.id end
            assert(found, "a hire stranded in an old save cannot be picked")
        end,
    },
    {
        name = "the city's rout notice says the haul and the gold are lost, and who died",
        fn = function()
            local src = assert(love.filesystem.read("states/hub.lua"), "cannot read states/hub.lua")
            assert(src:find("routNotice(", 1, true),
                "the hub no longer says the rout through Descent.routNotice")
            assert(src:find("pendingDead", 1, true) and src:find("pendingGoldLost", 1, true),
                "the rout notice no longer reads the dead hires and the gold lost")
            assert(Descent.routNotice(4, 340, {}) == "Routed on floor 4. The haul and 340 gold are lost.",
                Descent.routNotice(4, 340, {}))
            assert(Descent.routNotice(2, 0, {}) == "Routed on floor 2. The haul is lost.")
            assert(Descent.routNotice(2, nil, { "Bram" }) == "Routed on floor 2. The haul is lost. Bram died.")
            assert(Descent.routNotice(3, 15, { "A", "B" }) == "Routed on floor 3. The haul and 15 gold are lost. 2 hires died.")
        end,
    },
}
