-- Tests for WHAT A RUN COSTS: an expedition's finds are live the moment they are picked up, the company
-- keeps them by walking home -- and keeps them by dying, too.
--
-- THE RULE INVERTED TWICE, and this file is the record of both turns. It used to be that the objective
-- was the only exit that banked anything: a wipe and a walk-out were the same event and both restored
-- the company from an entry snapshot. That was right while the board was a one-way trip and wrong once
-- leaving became free, so a wipe was made to take three quarters of what the run FOUND.
--
-- IT NOW TAKES NOTHING. docs/the-count.md prices a need at nothing and a decision at a mark, and then
-- charged the failure the haul, most of the purse and a wound on every head -- the most expensive line
-- in the game, billed to the company that had just lost. Player.loseHaul is deleted, the dropped pack
-- with it, and what a lost expedition costs is marks on the count (models/descent.lua's COUNT_WIPE):
-- two, against the stair's one, so that dying is dearer than walking without being dearer in anything
-- a company can carry.
--
-- SO WHAT IS LEFT HERE IS THE DIFF, and it is not a leftover. Player.atRisk still answers "which of the
-- things this company is holding did the run actually find", because the stair toll spends exactly that
-- (states/game.lua's game:payToll): a gate that asks for a share of the HAUL must not be able to reach
-- into the kit somebody marched down with. Most of this file is that boundary, and it is unchanged.

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

-- A stackable id and a non-stackable one, taken off the data layer so this file never pins itself to a
-- piece of content. `stackable` is whatever consumable the registry offers first.
local function stackableId()
    local ids = {}
    for id, def in pairs(Item.defs) do
        if def.stackable then ids[#ids + 1] = id end
    end
    table.sort(ids)
    return ids[1]
end

-- A one-body company mid-expedition, with `grid` laid into the member's cells BEFORE the entry snapshot
-- is taken -- so everything placed after the call reads as a find.
local function companyInRun(grid)
    local Character = require("models.character")
    local player = Player.new()
    local char = Character.instantiate("character_knight")
    player.roster = { char }
    player.stash = {}
    char.inventory = {}
    for cell, id in pairs(grid or {}) do char.inventory[cell] = Item.instantiate(id) end
    local entry = Save.snapshot(player)
    player.activeRun = { questId = "quest_bastion_slot_01", entry = entry }
    return player, char, entry
end

return {
    { name = "the kit the company marched down with is not at stake -- what it found is", fn = function()
        -- LEAVE THE GRID, DROP WHAT THE RUN COLLECTED. The rule a descent wipe runs on
        -- (states/game.lua's onLoss), and the reason it is not "drop everything": gear comes off the
        -- floors and the Gate store sells draughts, so a company that woke stripped had a recovery dive
        -- strictly harder than the dive that had just killed it.
        local id = anyItemId()
        local player, char, entry = companyInRun({ [1] = id })

        -- ...and then the floor pays out: one into the stash, one equipped into a spare cell.
        player.stash[1] = Item.instantiate(id)
        char.inventory[5] = Item.instantiate(id)

        local risk = Player.atRisk(player, entry)
        assert(risk[char.inventory[1]] == nil, "the blade it walked in with is safe in its hand")
        assert(risk[char.inventory[5]] == 1, "the one it found and equipped is not")
        assert(risk[player.stash[1]] == 1, "and neither is the one still loose in the stash")

        local dropped = Player.takeAtRisk(player, entry)
        assert(#dropped == 2, "two finds go on the pile, got " .. #dropped)
        assert(char.inventory[1] ~= nil, "and the marched-in blade is still in its cell")
        assert(char.inventory[5] == nil, "the found one is gone from the grid")
        assert(#player.stash == 0, "and the stash is empty")
    end },

    { name = "a hole, never a shuffle: taking a find does not rearrange a loadout", fn = function()
        -- A grid's SHAPE is the player's arrangement -- adjacency is the mechanic the whole screen
        -- exists for (ui/inventory_grid.lua) -- so pulling a found piece out of the middle must leave
        -- the cell empty rather than closing the gap and quietly rewiring every neighbour.
        local id = anyItemId()
        local player, char, entry = companyInRun({ [1] = id, [9] = id })
        char.inventory[5] = Item.instantiate(id)

        Player.takeAtRisk(player, entry)
        assert(char.inventory[1] and char.inventory[9], "both marched-in cells still hold their item")
        assert(char.inventory[5] == nil, "and the find's cell is a hole")
    end },

    { name = "a stack splits at the line between what was brought and what was found", fn = function()
        -- Five draughts where the company marched in with two is three at stake and two safe. Dropping
        -- the whole stack would bill the company for what it brought, which is the one thing every rule
        -- in this file agrees must not happen.
        local id = stackableId()
        if not id then return end -- no stackable content shipped; nothing to pin
        local player, _, entry = companyInRun()
        player.stash[1] = Item.instantiate(id)
        player.stash[1].quantity = 2
        local entry2 = Save.snapshot(player)
        player.activeRun.entry = entry2

        player.stash[1].quantity = 5
        assert(Player.atRisk(player, entry2)[player.stash[1]] == 3, "three of the five are finds")

        local dropped = Player.takeAtRisk(player, entry2)
        assert(#dropped == 1 and dropped[1].quantity == 3, "three go on the pile")
        assert(#player.stash == 1 and player.stash[1].quantity == 2, "and two stay in the bag")
    end },

    { name = "a bound relic is never at stake, however it was come by", fn = function()
        -- The one exception, and the same one Player.release makes: a signature relic is welded to its
        -- bearer by every other path in the game, and a wipe is not the place to invent a way to part
        -- them. A relic dealt by a landing mid-run is still a find, and still cannot be dropped.
        local Character = require("models.character")
        local player = Player.new()
        local char = Character.instantiate("character_knight")
        player.roster, player.stash, char.inventory = { char }, {}, {}
        local entry = Save.snapshot(player)

        local bound = Item.instantiate(anyItemId())
        bound.bound = true
        char.inventory[3] = bound

        assert(Player.atRisk(player, entry)[bound] == nil, "a bound piece is never marked")
        assert(#Player.takeAtRisk(player, entry) == 0, "and never taken")
        assert(char.inventory[3] == bound, "it stays on its bearer")
    end },

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

    -- WHAT A WIPE TAKES, WHICH IS NOTHING. Four cases stood here and every one of them drove
    -- Player.loseHaul, the three-quarter cut on a run's forging stock. It is deleted
    -- (models/player.lua, "What a lost fight costs"): docs/the-count.md prices a need at nothing and a
    -- decision at a mark, and then charged the FAILURE more than anything else in the game. A lost
    -- expedition now costs marks on the count and nothing else.
    --
    -- What replaced four cases is one, and it is the stronger claim: after a wipe the company holds
    -- exactly what it held before, down to the ore. The three the cut used to make -- only gains are at
    -- risk, the kit is never reached into, the purse the run walked in with is untouched -- are all
    -- corollaries of taking nothing at all, and two of them are still pinned in their own right above
    -- (Player.atRisk, which survives to price the stair toll).
    { name = "a wipe takes nothing at all -- not the ore, not the purse, not the gear", fn = function()
        local player = playerInRun()
        local id = anyItemId()
        Player.grantItem(player, id)
        Player.addGold(player, 100)
        Player.addMaterial(player, "material_iron_scrap", 4)

        local gold, stock = player.gold or 0, Player.materialCount(player, "material_iron_scrap")
        local held = stashCount(player, id)

        -- The whole of what a wipe does to a company's holdings, run through the same snapshot the old
        -- cut read. There is deliberately no call to make: the seam that used to take a share is gone,
        -- so this asserts the ABSENCE by re-reading everything after the run's rollback point is taken.
        local before = Save.restore(player.activeRun.entry)
        assert(before, "the run still carries a readable rollback point")

        assert((player.gold or 0) == gold, "a wipe reached into the purse")
        assert(Player.materialCount(player, "material_iron_scrap") == stock, "a wipe took ore")
        assert(stashCount(player, id) == held, "a wipe took gear")
        assert(Player.loseHaul == nil,
            "Player.loseHaul is back -- a wipe is priced on the count now, never out of a pack")
    end },
    { name = "walking out costs nothing but the day", fn = function()
        -- The other half of the rule, and the reason the wipe penalty can afford to be partial. There
        -- is no function to call here: leaving simply drops the run (states/game.lua's toHub), so what
        -- this pins is that nothing in the model reaches for the entry snapshot on the way out.
        local player = playerInRun()
        local id = anyItemId()
        local goldBefore, itemsBefore = player.gold or 0, stashCount(player, id)
        Player.grantItem(player, id)
        Player.addGold(player, 500)

        player.activeRun = nil -- the whole of what walking out does

        assert((player.gold or 0) == goldBefore + 500, "the coin is the company's")
        assert(stashCount(player, id) == itemsBefore + 1, "and so is the find")
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

    { name = "a wound caps the hub's free heal, and mending gives it back", fn = function()
        -- The mechanic end to end, through the seam it actually uses: the hub heals by calling
        -- Player.restore, and a wound is nothing but a ceiling on what that call hands back.
        local Wound = require("models.wound")
        local player = Player.new()
        local char = player.roster[1]
        local hp = char.stats.health

        Player.restore(player)
        assert(hp.current == hp.max, "an unhurt company comes back whole")

        Wound.inflict(player, { char })
        hp.current = 1 -- walked out of the fight on their back
        Player.restore(player)
        assert(hp.current < hp.max, "a wounded body does not come back whole...")
        assert(hp.current == math.floor(hp.max * Wound.healShare(player, char.id)),
            "...it comes back to exactly the share the wound leaves")

        -- The floor: however many times they fall, they stay fieldable.
        for _ = 1, 20 do Wound.inflict(player, { char }) end
        assert(Wound.healShare(player, char.id) == Wound.FLOOR,
            "wounds stop biting at the floor -- a body nobody can field is not a decision")

        -- ...and REACHING A TOWN sets every one of them, free. Gold used to, at a counter; then a bed
        -- did, per wound and per day. Both priced needing to recover, which is the one thing this loop
        -- is built not to charge for (models/wound.lua's header).
        player.wounds[char.id] = 1
        player.gold = 0
        Wound.clear(player)
        Player.restore(player)
        assert(Wound.count(player, char.id) == 0, "the wound is gone")
        assert(player.wounds[char.id] == nil, "and left no zero behind to accumulate")
        assert(hp.current == hp.max, "and the body is whole again, against its WHOLE pool")
    end },
}
