-- Tests for the EXTRACTION rule: an overworld run's finds are live and usable the moment they are
-- picked up, but they are not the player's until the objective banks them. Any other way out -- a wipe,
-- a walk-out -- puts the company back exactly as it marched in.
--
-- The rule lives in states/game.lua (rollbackRun / the objective's clearRun), which cannot be driven
-- headlessly. What CAN be pinned, and what the whole thing actually rests on, is the pair underneath it:
-- the entry snapshot survives a save, and restoring it takes back what the run added while leaving what
-- the run brought alone. Everything is driven through the real serializer, so a value the encoder cannot
-- handle fails here rather than in a player's save.

local Overworld = require("models.overworld")
local Save = require("models.save")
local Player = require("models.player")
local Item = require("models.item")

local function genGrid()
    return Overworld.generate({
        cols = 25, rows = 17, seed = 42, biome = "forest",
        encounterCount = 4, keyCount = 0, objective = { name = "Boss" },
        encounters = { { kind = "combat", weight = 3 }, { kind = "treasure", weight = 1 } },
    })
end

local function reserialize(data)
    return Save.decode("return " .. Save.encode(data, 0))
end

-- A player mid-expedition: an entry snapshot parked on the run, exactly as states/game.lua parks it.
local function playerInRun()
    local player = Player.new()
    local g = genGrid()
    local entry = Save.snapshot(player) -- taken BEFORE anything is found, with no run attached
    player.activeRun = {
        questId = "quest_bastion_slot_01", prestige = 1, grid = g,
        map = { px = g.start.x, py = g.start.y, keysHeld = {}, cacheHaul = {} },
        abilityState = {}, entry = entry,
    }
    return player, entry
end

local function stashCount(player, id)
    local n = 0
    for _, it in ipairs(player.stash or {}) do
        if it.id == id then n = n + (it.quantity or 1) end
    end
    return n
end

-- The first item id the data layer offers, so this spec never pins itself to a piece of content.
local function anyItemId()
    local ids = {}
    for id in pairs(Item.defs) do ids[#ids + 1] = id end
    table.sort(ids)
    return ids[1]
end

return {
    { name = "the rollback point rides with the run through a save", fn = function()
        local player = playerInRun()
        local restored = Save.restore(reserialize(Save.snapshot(player)))
        assert(restored.resumeRun, "the run round-trips")
        assert(restored.resumeRun.entry, "the entry snapshot came back with it")
        assert(restored.resumeRun.entry.version == Save.VERSION,
            "the entry snapshot is a real player snapshot, not a husk")
        -- Without this a player could quit mid-quest, choose Continue, and wipe with nothing to roll
        -- back to -- silently keeping a run that was supposed to cost them everything.
        assert(#(restored.resumeRun.entry.roster or {}) > 0, "the company it captured survived the trip")
    end },

    { name = "a wipe takes what the run found", fn = function()
        local player = playerInRun()
        local id = anyItemId()
        -- Measured, never assumed: a fresh company already owns gear, coin and a little stock, so every
        -- check here is a DELTA. An absolute figure would be pinning this spec to the starting kit.
        local before = stashCount(player, id)
        local goldBefore = player.gold or 0
        local stockBefore = Player.materialCount(player, "material_iron_scrap")

        -- The expedition finds things. They land in the stash immediately -- live, equippable, spendable.
        Player.grantItem(player, id)
        Player.grantItem(player, id)
        Player.addGold(player, 250)
        Player.addMaterial(player, "material_iron_scrap", 4)
        assert(stashCount(player, id) == before + 2, "the finds are real while the run is under way")

        -- ...and the run ends any way but through the objective.
        local rolled = Save.restore(player.activeRun.entry)
        assert(rolled, "the entry snapshot restores")
        for k, v in pairs(rolled) do player[k] = v end

        assert(stashCount(player, id) == before, "found items went back")
        assert((player.gold or 0) == goldBefore, "found gold went back")
        assert(Player.materialCount(player, "material_iron_scrap") == stockBefore,
            "found materials went back")
    end },

    { name = "gold SPENT mid-run comes back too", fn = function()
        -- Otherwise a forfeit launders run gold into permanent hub goods: buy a relic at a Fence, walk
        -- out, keep the relic's effect on the books while the coin is refunded by the next run. Same
        -- hole as keeping the loot, entered from the other side.
        local player = playerInRun()
        local goldBefore = player.gold or 0
        Player.addGold(player, 100)
        assert(Player.spendGold(player, 120), "the run spends at a Fence")
        assert((player.gold or 0) < goldBefore, "the company is out of pocket mid-run")

        local rolled = Save.restore(player.activeRun.entry)
        for k, v in pairs(rolled) do player[k] = v end
        assert((player.gold or 0) == goldBefore, "the purse is back where it started")
    end },

    { name = "what the company MARCHED IN WITH is never at stake", fn = function()
        -- The bound that keeps a lost expedition from reading as a ruined save. A wipe costs what the
        -- run found; it must never reach into the kit, the forge levels or the roster.
        local player = Player.new()
        local id = anyItemId()
        Player.grantItem(player, id)
        local owned = stashCount(player, id)
        local goldBefore = player.gold or 0
        local rosterBefore = #player.roster
        Player.addMaterial(player, "material_iron_scrap", 7) -- banked from an EARLIER, completed run
        local stockOwned = Player.materialCount(player, "material_iron_scrap")

        local entry = Save.snapshot(player)
        player.activeRun = { questId = "quest_bastion_slot_01", prestige = 1, entry = entry }

        Player.grantItem(player, id) -- and then this run finds one more
        local rolled = Save.restore(player.activeRun.entry)
        for k, v in pairs(rolled) do player[k] = v end

        assert(stashCount(player, id) == owned, "the item brought in is still owned; only the find went")
        assert((player.gold or 0) == goldBefore, "the purse brought in is untouched")
        assert(#player.roster == rosterBefore, "the company is intact")
        assert(Player.materialCount(player, "material_iron_scrap") == stockOwned,
            "stock banked by an earlier run is not clawed back by this one's failure")
    end },

    { name = "the entry snapshot carries no run of its own", fn = function()
        -- Taken with the run detached on purpose (states/game.lua nils activeRun first). If it nested a
        -- run inside itself, every quest entered would fold the last one's board into the save.
        local player = playerInRun()
        assert(player.activeRun.entry.run == nil,
            "the rollback point must not contain a board, or saves grow a run per quest")
    end },

    { name = "an older run with no rollback point still loads", fn = function()
        -- Saves written before the run kept an entry snapshot. They cannot roll back -- there is nothing
        -- to roll back TO -- but the board must still be playable rather than dropped out from under a
        -- player standing on it.
        local player = playerInRun()
        local snap = reserialize(Save.snapshot(player))
        snap.run.entry = nil
        local restored = Save.restore(snap)
        assert(restored.resumeRun, "the run still restores without an entry snapshot")
        assert(restored.resumeRun.entry == nil, "and it honestly reports having none")
    end },
}
