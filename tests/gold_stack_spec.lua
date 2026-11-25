-- GOLD IS A STACK IN THE STASH, AND NONE OF IT GOES DOWN (2026-11-24, data/materials/material_gold.lua).
--
-- `player.gold` is a view onto the stack in whichever container the company can reach (Player.bindGold):
-- the stash in town, the bag underground. So the town's coin takes one slot on the shelf, a run spends
-- only what it found, a wipe loses the bag's coin, and climbing out lands it on the shelf.

local Character = require("models.character")
local Descent = require("models.descent")
local Material = require("models.material")
local Player = require("models.player")
local Save = require("models.save")
local SendUp = require("models.send_up")

local function stacks(list)
    local n, q = 0, 0
    for _, it in ipairs(list or {}) do
        if Material.isCurrency(it) then n, q = n + 1, q + (it.quantity or 0) end
    end
    return n, q
end

local function goDown(player)
    local rowan = player.roster[1]
    local run = Descent.new(player, 1357)
    Descent.setParty(run, { rowan.id })
    player.descentRun = run
    run.entry = Save.snapshot(player)
    assert(Player.packOpen(player), "the fixture is not underground")
    return run
end

return {
    {
        name = "in town the purse is one stack on the shelf, and spending it to nothing frees the slot",
        fn = function()
            local player = Player.new()
            local n, q = stacks(player.stash)
            assert(n == 1 and q == player.gold and q > 0, "the opening purse is not one stack on the shelf")
            Player.addGold(player, 1000)
            n, q = stacks(player.stash)
            assert(n == 1 and q == player.gold, "earning made a second stack")
            assert(Player.spendGold(player, player.gold), "the whole purse could not be spent")
            assert(player.gold == 0 and stacks(player.stash) == 0, "an empty purse still takes a slot")
            assert(not Player.spendGold(player, 1), "spent coin the company does not have")
        end,
    },
    {
        name = "underground the purse is the bag's, empty at the stair, and the shelf's coin is out of reach",
        fn = function()
            local player = Player.new()
            Player.addGold(player, 500)
            local banked = player.gold
            goDown(player)
            assert(player.gold == 0, "gold went down the stair: the bag holds " .. player.gold)
            assert(not Player.spendGold(player, 10), "a purchase underground reached the town's coin")
            Player.addGold(player, 120)
            local n, q = stacks(player.pack)
            assert(n == 1 and q == 120, "coin found underground did not land in the bag")
            assert(select(2, stacks(player.stash)) == banked, "the town's coin moved")
            assert(Player.spendGold(player, 20) and player.gold == 100, "a road purchase did not spend the bag")
        end,
    },
    {
        name = "a wipe loses the bag's coin and never the shelf's; climbing out banks it in one slot",
        fn = function()
            local player = Player.new()
            local banked = player.gold
            local run = goDown(player)
            Player.addGold(player, 340)
            local out = Descent.wipe(player, run)
            assert(out.gold == 340, "the wipe reported " .. tostring(out.gold) .. " of 340 lost")
            assert(player.gold == 0 and stacks(player.pack) == 0, "the bag's coin survived the wipe")
            assert(select(2, stacks(player.stash)) == banked, "the wipe reached the shelf's coin")

            player = Player.new()
            banked = player.gold
            goDown(player)
            Player.addGold(player, 75)
            Player.unpack(player)
            player.descentRun = nil
            local n, q = stacks(player.stash)
            assert(n == 1 and q == banked + 75, "climbing out did not merge the bag's coin into one stack")
        end,
    },
    {
        name = "the hoist can send coin up, and what went up survives a wipe",
        fn = function()
            local player = Player.new()
            local banked = player.gold
            local run = goDown(player)
            Player.addGold(player, 200)
            local coin
            for _, it in ipairs(SendUp.candidates(player)) do
                if Material.isCurrency(it) then coin = it end
            end
            assert(coin, "the bag's coin is not offered to the hoist")
            SendUp.send(player, { coin }, SendUp.HOIST_LIMIT)
            Descent.wipe(player, run)
            player.descentRun = nil
            assert(player.gold == banked + 200, "the coin sent up was lost: " .. player.gold)
            local n = stacks(player.stash)
            assert(n == 1, "the coin sent up sits in " .. n .. " stacks on the shelf")
        end,
    },
    {
        name = "a save carries the stack once, and an old save's number becomes the stack",
        fn = function()
            local player = Player.new()
            Player.addGold(player, 321)
            local want = player.gold
            local back = Save.restore(Save.decode("return " .. Save.encode(Save.snapshot(player), 0)))
            assert(back.gold == want, "the purse came back as " .. back.gold .. " of " .. want)
            assert(stacks(back.stash) == 1, "the save doubled the stack")

            local old = Save.snapshot(Player.new())
            local filtered = {}
            for _, it in ipairs(old.stash or {}) do
                if not Material.isCurrency(it) then filtered[#filtered + 1] = it end
            end
            old.stash, old.gold = filtered, 777
            local restored = Save.restore(Save.decode("return " .. Save.encode(old, 0)))
            assert(restored.gold == 777 and stacks(restored.stash) == 1,
                "an old save's purse did not become one stack of 777")
        end,
    },
    {
        name = "gold is not forging stock: no tally, no list, and clearing stock leaves it",
        fn = function()
            local player = Player.new()
            assert(Material.tally(player)[Material.GOLD] == nil, "the purse is tallied as forging stock")
            for _, m in ipairs(Material.list()) do
                assert(m.id ~= Material.GOLD, "the purse is listed as forging stock")
            end
            local purse = player.gold
            Player.setMaterials(player, {})
            assert(player.gold == purse, "clearing forging stock took the purse")
            local ok = Character.canCarry(player.roster[1], Material.instantiate(Material.GOLD, 5))
            assert(not ok, "a body may wear the purse in a grid cell")
        end,
    },
}
