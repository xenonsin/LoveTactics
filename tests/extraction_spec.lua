-- Tests for WHAT A RUN COSTS: an overworld run's finds are live the moment they are picked up, the
-- company keeps them by walking home, and a WIPE takes most of the coin and ore back.
--
-- THE RULE INVERTED, and this file is the record of it. It used to be that the objective was the only
-- exit that banked anything -- a wipe and a walk-out were the same event, and both restored the company
-- from an entry snapshot. That was right while the board was a one-way trip. It is wrong now that a day
-- is the unit and leaving is free: with a voluntary exit keeping everything, a total wipe penalty makes
-- the last fight before you turn back an all-or-nothing coin flip, and the sensible play is to leave
-- after the first cache.
--
-- So: walking out keeps everything, and losing takes Player.WIPE_LOSS of what the run FOUND -- gold and
-- forging stock, never the items, never the wounds, never what was carried in.
--
-- These cases used to drive `Save.restore(entry)` and copy it over the player, which was the state's
-- own rollback spelled out by hand. That is why they kept passing after the rule changed: they were
-- testing the SNAPSHOT, which still works, while the rule above it had been replaced. The arithmetic
-- moved to Player.loseHaul so it can be driven directly, and these drive that.

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

        -- ...and then the company loses a fight.
        local entry = Save.restore(player.activeRun.entry)
        assert(entry, "the entry snapshot restores")
        local taken = Player.loseHaul(player, entry)

        -- THREE QUARTERS OF THE ORE, and the quarter that survives is the point: a wipe deep in a good
        -- run is a bad day rather than a wasted one.
        assert(Player.materialCount(player, "material_iron_scrap") == stockBefore + 1,
            "one of the four scrap survives the rout")

        -- GOLD IS NOT TOUCHED, and this assertion is the reversal rather than a relaxation of the old
        -- one. It used to take 187 of the 250. The economy split (models/scrip.lua): a run's coin is
        -- scrip and burns at every exit, and the campaign's coin is no longer a number a run can gain --
        -- it arrives as valuables in the pack, and the pack hits the floor where the company fell
        -- (Descent.dropPack). The cut is levied by the pile now, which is recoverable where a percentage
        -- never was. Billing both would charge one loss twice.
        assert(taken.gold == 0, "loseHaul reported taking gold, which the pack takes now")
        assert((player.gold or 0) == goldBefore + 250,
            "a wipe took gold -- the pile is the penalty (models/player.lua's loseHaul)")

        -- THE ITEMS STAY, HERE. A sword out of a chest is carried by a body, and the bodies came home;
        -- what puts the run's finds on the floor is Descent.dropPack, which is a different seam with a
        -- spec of its own. This one is only about what the CUT takes.
        assert(stashCount(player, id) == before + 2,
            "a wipe's cut drops ore, never the gear")
    end },

    { name = "a run that spent more than it found is not billed the difference", fn = function()
        -- Only GAINS are at risk. A company that bought a blade at the Merchant and then lost the fight
        -- keeps the blade and keeps what is left of its purse: there is no negative haul to confiscate,
        -- and reaching into the money they walked in with would make the Merchant a trap.
        local player = playerInRun()
        Player.addGold(player, 100)
        assert(Player.spendGold(player, 220), "the run spends at the Merchant")
        local pocket = player.gold or 0

        local before = Save.restore(player.activeRun.entry)
        local taken = Player.loseHaul(player, before)
        assert(taken.gold == 0, "nothing was gained, so nothing is taken")
        assert((player.gold or 0) == pocket, "and the purse is left exactly where the run left it")
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

        Player.grantItem(player, id) -- and then this run finds one more, and loses the fight
        Player.loseHaul(player, Save.restore(player.activeRun.entry))

        assert(stashCount(player, id) == owned + 1, "the find stays -- a wipe never takes gear")
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

    { name = "a wipe takes the coin and leaves the wounds", fn = function()
        -- WOUNDS OUTLIVE THE RUN THAT CAUSED THEM -- the whole point of an injury -- and this used to be
        -- delicate: the old rollback copied EVERY key of the entry snapshot onto the live player, so
        -- `wounds` had to be held across the copy by hand or a wipe handed the company back whole at
        -- the instant it was hurt worst.
        --
        -- Player.loseHaul touches two fields by name instead of copying a whole snapshot, so the danger
        -- is gone by construction rather than by a line somebody has to remember. The case stays,
        -- because "a wipe does not un-wound you" is a rule worth pinning however it is implemented.
        local Wound = require("models.wound")
        local player = playerInRun()
        player.wounds = {}

        -- Marched in with one old wound...
        Wound.inflict(player, { { id = "character_rowan" } })
        local entry = reserialize(Save.snapshot(player))

        -- ...and the run went badly: ore found, and two more bodies down. Ore rather than coin, because
        -- ore is what the cut still takes (models/scrip.lua) -- pinning the wounds against a resource
        -- loseHaul no longer touches would be pinning them against nothing.
        local stockBefore = Player.materialCount(player, "material_iron_scrap")
        Player.addMaterial(player, "material_iron_scrap", 4)
        Wound.inflict(player, { { id = "character_rowan" }, { id = "character_knight" } })
        assert(Wound.count(player, "character_rowan") == 2, "two bad fights, two wounds")

        Player.loseHaul(player, Save.restore(entry))

        assert(Wound.count(player, "character_rowan") == 2,
            "a wipe must not un-wound the company -- an injury outliving its run is the whole mechanic")
        assert(Wound.count(player, "character_knight") == 1, "including one taken for the first time")
        assert(Player.materialCount(player, "material_iron_scrap") == stockBefore + 1,
            "while most of the ore it found is gone")
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
