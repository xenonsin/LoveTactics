-- THE BAG, THE HOIST AND THE RIFT MULE (2026-11-24, models/send_up.lua).
--
--   * nothing is packed in town: a company walks down with its grids, and the town screens show the stash;
--   * the bag has no bottom underground, and a wipe empties all of it (Descent.wipe);
--   * a hoist on every floor sends a few pieces from the bag to the stash, once;
--   * the Rift Mule, found once on floor five, sends a few pieces up from the map's button,
--     then is away for SendUp.MULE_REST fights. It never fights.
--
-- What a sent piece must survive is the wipe's DIFF (Player.atRisk reads the stash too), so the cases
-- below wipe after every send rather than only counting where things landed.

local Character = require("models.character")
local Descent = require("models.descent")
local Item = require("models.item")
local Player = require("models.player")
local Save = require("models.save")
local SendUp = require("models.send_up")

local SWORD = "weapon_iron_sword"
local DAGGER = "weapon_iron_dagger"

-- A company of one standing on floor one: Rowan, the entry snapshot taken, the bag open.
local function underground()
    local player = Player.new()
    local rowan = Character.instantiate("character_rowan")
    player.roster = { rowan }
    Player.setMaterials(player, {})
    local run = Descent.new(player, 2468)
    Descent.setParty(run, { rowan.id })
    player.descentRun = run
    run.entry = Save.snapshot(player)
    assert(Player.packOpen(player), "the fixture is not underground")
    return player, run, rowan
end

local function count(list, id)
    local n = 0
    for _, it in ipairs(list or {}) do if it.id == id then n = n + (it.quantity or 1) end end
    return n
end

return {
    {
        name = "a wipe empties the whole bag, finds and forging stock alike",
        fn = function()
            local player, run, rowan = underground()
            for _ = 1, 30 do Player.stow(player, Item.instantiate(SWORD)) end
            -- A piece the company walked in with, moved from a grid into the bag down here: it is in
            -- the bag, so it goes with the bag.
            local slot = Character.firstEmptySlot(rowan)
            rowan.inventory[slot] = Item.instantiate(DAGGER)
            run.entry = Save.snapshot(player)
            Player.addToPack(player, rowan.inventory[slot])
            rowan.inventory[slot] = nil
            Player.addMaterial(player, "material_iron_scrap", 3)
            local ore = 0
            for _, it in ipairs(player.pack) do if it.type == "material" then ore = ore + 1 end end
            assert(ore > 0, "the fixture's ore did not reach the bag")

            local out = Descent.wipe(player, run)
            assert(count(player.pack, SWORD) == 0 and count(player.pack, DAGGER) == 0,
                "the wipe left something in the bag")
            assert(count(player.stash, SWORD) == 0, "a find escaped the wipe onto the shelf")
            assert(out.lost >= 31, "the wipe counted " .. out.lost .. " of 31 pieces lost")
            assert(#player.pack == 0, "the wipe left the ore in the bag")
            assert(Player.materialCount(player, "material_iron_scrap") == 0, "the ore escaped the wipe")
        end,
    },
    {
        name = "forging stock can be sent up, and what went up survives a wipe",
        fn = function()
            local player, run = underground()
            Player.addMaterial(player, "material_iron_scrap", 4)
            Player.stow(player, Item.instantiate(SWORD))
            local ore
            for _, it in ipairs(SendUp.candidates(player)) do
                if it.type == "material" then ore = it end
            end
            assert(ore, "forging stock in the bag is not offered to the hoist")
            assert(#SendUp.send(player, { ore }, SendUp.HOIST_LIMIT) == 1, "the ore did not go up")
            Descent.wipe(player, run)
            assert(Player.materialCount(player, "material_iron_scrap") == 4,
                "the wipe reached the ore already sent up")
            assert(count(player.pack, SWORD) == 0, "the sword that stayed in the bag survived")
        end,
    },
    {
        name = "the bag holds any number underground, and nothing is refused",
        fn = function()
            local player = underground()
            for _ = 1, 60 do Player.stow(player, Item.instantiate(SWORD)) end
            assert(Descent.carried(player) == 60, "the bag stopped taking finds at " .. Descent.carried(player))
            assert(Descent.carryRoom(player) == math.huge, "the bag reports a ceiling")
        end,
    },
    {
        name = "the hoist sends up to its limit to the stash, and what it sent survives a wipe",
        fn = function()
            local player, run = underground()
            for _ = 1, 5 do Player.stow(player, Item.instantiate(SWORD)) end
            Player.stow(player, Item.instantiate(DAGGER))
            local limit = SendUp.limit(player, "hoist")
            assert(limit == SendUp.HOIST_LIMIT, "a company with no bonus sends " .. limit)

            local all = SendUp.candidates(player)
            assert(#all == 6, "the candidates are not the bag")
            local sent = SendUp.send(player, all, limit)
            assert(#sent == limit, "the hoist sent " .. #sent .. " of a limit of " .. limit)
            assert(#player.pack == 6 - limit, "the sent pieces are still in the bag")
            assert(count(player.stash, SWORD) + count(player.stash, DAGGER) == limit,
                "the sent pieces did not reach the stash")

            -- THE POINT OF IT: they are the company's now, and the wipe's diff knows it.
            Descent.wipe(player, run)
            assert(count(player.stash, SWORD) + count(player.stash, DAGGER) == limit,
                "the wipe took back what the hoist sent up")
            assert(#player.pack == 0, "the wipe left the rest of the bag")
        end,
    },
    {
        name = "the Rift Mule: sent once found, then away for its rest, and the rest rides a save",
        fn = function()
            local player, run = underground()
            Player.stow(player, Item.instantiate(SWORD))
            local ok, why = SendUp.muleReady(player)
            assert(not ok and why == "none", "a company that never found the mule was offered one")

            SendUp.unlockMule(player)
            assert(SendUp.muleReady(player), "a found mule at home with a full bag was not ready")

            for _ = 1, 4 do Player.stow(player, Item.instantiate(DAGGER)) end
            local sent = SendUp.dispatchMule(player, SendUp.candidates(player))
            assert(#sent == SendUp.MULE_LIMIT, "the mule took " .. #sent .. " of " .. SendUp.MULE_LIMIT)
            assert(SendUp.muleAway(player) == SendUp.MULE_REST, "the mule is not away for its rest")
            local ok2, why2 = SendUp.muleReady(player)
            assert(not ok2 and why2 == "away", "a mule up top was ready again")

            local back = Descent.restore(Descent.snapshot(run))
            assert(back.muleRest == SendUp.MULE_REST, "the mule's rest did not ride the run's save")

            for i = 1, SendUp.MULE_REST do
                local home = SendUp.tickMule(player)
                assert(home == (i == SendUp.MULE_REST), "the mule came home after " .. i .. " fights")
            end
            assert(SendUp.muleAway(player) == 0 and SendUp.muleReady(player), "the mule did not come back")
        end,
    },
    {
        name = "an empty pick spends neither the mule nor the hoist; town opens neither",
        fn = function()
            local player, run = underground()
            SendUp.unlockMule(player)
            local ok, why = SendUp.muleReady(player)
            assert(not ok and why == "empty", "an empty bag offered the mule")
            assert(#SendUp.dispatchMule(player, {}) == 0 and SendUp.muleAway(player) == 0,
                "sending nothing sent the mule away")
            run.entry = nil
            local ok2, why2 = SendUp.muleReady(player)
            assert(not ok2 and why2 == "town", "the mule is offered in town")
        end,
    },
    {
        name = "the town screens no longer pack a bag, and the bag goes down empty",
        fn = function()
            for _, path in ipairs({ "states/hub.lua", "states/gate.lua" }) do
                local src = assert(love.filesystem.read(path), "cannot read " .. path)
                assert(not src:find('pool = "both"', 1, true) and not src:find('"both" or nil', 1, true),
                    path .. " still opens the pack band")
            end
            local gate = love.filesystem.read("states/gate.lua"):gsub("\r", "")
            local from = gate:find("local function descend()", 1, true)
            local unpack = gate:find("Player.unpack(gate.player)", from, true)
            local switch = gate:find("State.switch", from, true)
            assert(unpack and unpack < switch, "the stair does not empty an old save's bag before going down")
        end,
    },
    {
        name = "the mule waits on floor five until found, never fights, and its unlock rides a save",
        fn = function()
            local player = Player.new()
            local five = Descent.muleStops(player, SendUp.MULE_FLOOR)
            assert(#five == 1 and five[1] == "mule", "floor five does not guarantee the mule")
            assert(#Descent.muleStops(player, 4) == 0, "the mule is guaranteed off floor five")
            assert(SendUp.unlockMule(player), "the first find did not unlock the mule")
            assert(not SendUp.unlockMule(player), "a second find unlocked it again")
            assert(#Descent.muleStops(player, SendUp.MULE_FLOOR) == 0, "a found mule is placed again")
            local back = Save.restore(Save.decode("return " .. Save.encode(Save.snapshot(player), 0)))
            assert(SendUp.muleUnlocked(back), "the mule did not ride the save")
            assert(not SendUp.muleUnlocked(Player.new()), "a new company starts with the mule")
            -- It never fights: no item, no body, and the battle does not seat one.
            assert(not Item.defs.utility_rift_mule and not Character.defs.character_rift_mule,
                "the mule is still an item or a body")
            local battle = love.filesystem.read("states/battle.lua")
            assert(not battle:find("send_up", 1, true), "the battle still seats a mule")
        end,
    },
}
