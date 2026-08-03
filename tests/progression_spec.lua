-- Tests for the progression layer: the save round trip, the gold/prestige/quest-standing
-- economy, vendor stock derivation and rank gating, quest sponsorship and completion, and
-- the composable `protect` objective.
--
-- The save specs write to a throwaway filename so a developer's real save is never touched.

local Player = require("models.player")
local Vendor = require("models.vendor")
local Quest = require("models.quest")
local Item = require("models.item")
local Discipline = require("models.discipline")
local Save = require("models.save")
local Character = require("models.character")
local Combat = require("models.combat")
local Arena = require("models.arena")
local Growth = require("models.growth")

-- Run `fn` with Save pointed at a scratch file, cleaning up afterwards either way.
local function withScratchSave(fn)
    local real = Save.FILE
    Save.FILE = "save_spec_scratch.lua"
    local ok, err = pcall(fn)
    Save.clear()
    Save.FILE = real
    if not ok then error(err, 0) end
end

local function arena(cols, rows, objective)
    local tiles = {}
    for y = 1, rows do
        tiles[y] = {}
        for x = 1, cols do
            tiles[y][x] = { type = "ground", moveCost = 1, walkable = true }
        end
    end
    return { cols = cols, rows = rows, tiles = tiles, objective = objective or { type = "killAll" } }
end

local function unit(id, x, y, control)
    return { char = Character.instantiate(id), x = x, y = y, control = control }
end

local function playerAt(prestige)
    local p = Player.new()
    p.prestige = prestige
    return p
end

return {
    -- ---------------------------------------------------------------- economy
    {
        name = "spendGold refuses a purchase the player cannot afford, and charges nothing",
        fn = function()
            local p = Player.new()
            p.gold = 100

            assert(Player.spendGold(p, 40) == true, "should afford 40")
            assert(p.gold == 60, "gold should drop to 60")

            assert(Player.spendGold(p, 61) == false, "should not afford 61")
            assert(p.gold == 60, "a refused purchase must not charge")

            assert(Player.spendGold(p, 60) == true, "spending the exact balance is allowed")
            assert(p.gold == 0, "gold should be spent to zero")
        end,
    },
    {
        name = "Quest.sponsorProgress counts a vendor's finished quests; unknown vendors read zero",
        fn = function()
            local Quest = require("models.quest")
            local p = Player.new()
            assert(Quest.sponsorProgress(p, "colosseum") == 0, "unseen vendor should read 0")
            p.completedQuests = {
                quest_colosseum_slot_01 = true,
                quest_colosseum_slot_02 = true,
                quest_bastion_slot_01 = true, -- a different sponsor must not count toward the colosseum
            }
            assert(Quest.sponsorProgress(p, "colosseum") == 2, "only the colosseum's own quests count")
            assert(Quest.sponsorProgress(p, "bastion") == 1, "each sponsor counts independently")
        end,
    },
    {
        name = "Vendor.tier climbs one wave per TIERS threshold crossed, and caps at the top",
        fn = function()
            local T = Vendor.TIERS -- { 0, 3, 6, 10 }
            for i = 2, #T do
                assert(Vendor.tier(T[i] - 1) == i - 1,
                    "one short of threshold " .. i .. " should stay a wave lower")
                assert(Vendor.tier(T[i]) == i,
                    "hitting threshold " .. i .. " should open wave " .. i)
            end
            assert(Vendor.tier(99999) == #T, "tier should cap at the top wave")
        end,
    },
    {
        name = "Player.restore refills every roster member's resources, leaving flat stats alone",
        fn = function()
            local p = Player.new()
            local knight = p.roster[1]

            knight.stats.health.current = 1
            knight.stats.mana.current = 0
            knight.stats.stamina.current = 3
            local movement = knight.stats.movement

            Player.restore(p)

            assert(knight.stats.health.current == knight.stats.health.max, "health should refill")
            assert(knight.stats.mana.current == knight.stats.mana.max, "mana should refill")
            assert(knight.stats.stamina.current == knight.stats.stamina.max, "stamina should refill")
            assert(knight.stats.movement == movement, "flat stats must not be touched")
        end,
    },
    {
        name = "Player.restore reaches roster members who are not in the active party",
        fn = function()
            local p = Player.new()
            local benched = p.roster[#p.roster]
            Player.removeFromParty(p, benched)
            benched.stats.health.current = 5

            Player.restore(p)
            assert(benched.stats.health.current == benched.stats.health.max,
                "a benched character rests too")
        end,
    },

    -- ----------------------------------------------------------------- vendor
    {
        name = "vendor registry discovers all seven class vendors, each claiming one deadly sin",
        fn = function()
            local claimed = {}
            for _, id in ipairs({ "colosseum", "cathedral", "hunters_lodge", "bastion",
                                  "arcanum", "undercroft", "alchemist" }) do
                local def = Vendor.defs[id]
                assert(def, id .. " vendor missing")
                assert(def.sin, id .. " names no sin")
                assert(not claimed[def.sin], "two vendors claim " .. tostring(def.sin))
                claimed[def.sin] = true
            end
            -- Seven vendors, seven sins, one each: the shape the whole endgame hangs off.
            for _, sin in ipairs({ "wrath", "lust", "gluttony", "sloth", "pride", "greed", "envy" }) do
                assert(claimed[sin], "no vendor claims " .. sin)
            end
        end,
    },
    {
        name = "Vendor.stock sells only items of its own class, and only priced ones",
        fn = function()
            local stock = Vendor.stock("undercroft", 4)
            assert(#stock > 0, "the Undercroft should stock something")

            local ids = {}
            for _, entry in ipairs(stock) do
                ids[entry.id] = true
                -- A discipline item is a legitimate guest on a parent's shelf even when its own `class`
                -- is the OTHER parent (docs/classes.md): a Poacher item (rogue x hunter) sits on the
                -- rogue shelf whether its home class is rogue or hunter.
                local bp = Item.defs[entry.id]
                local onShelf = bp.class == "rogue"
                for _, p in ipairs(bp.discipline and Discipline.parents(bp.discipline) or {}) do
                    if p == "rogue" then onShelf = true end
                end
                assert(onShelf, entry.id .. " is on the rogue shelf without being a rogue item or a rogue-discipline guest")
                assert(entry.price, entry.id .. " is for sale with no price")
            end

            assert(ids.ability_pickpocket, "pickpocket should be a rogue item")
            assert(not ids.iron_sword, "the iron sword is a fighter item, not a rogue one")
        end,
    },
    {
        name = "Vendor.stock shows quest-locked items, flagged rather than hidden",
        fn = function()
            local low = Vendor.stock("colosseum", 0)
            local high = Vendor.stock("colosseum", 999)
            assert(#low == #high, "the shelf is the same length at every quest count")

            -- A discipline item carries a SECOND lock (its discipline must be unlocked) that quests never
            -- lift, so it is not part of this quest-only measure -- count only quest-gated wares.
            local lockedAtLow, lockedAtHigh = 0, 0
            for _, e in ipairs(low) do if e.locked and not e.discipline then lockedAtLow = lockedAtLow + 1 end end
            for _, e in ipairs(high) do if e.locked and not e.discipline then lockedAtHigh = lockedAtHigh + 1 end end

            assert(lockedAtLow > 0, "a player with no quests done should see items they cannot buy yet")
            assert(lockedAtHigh == 0, "a player past every gate should have everything quest-unlocked")
        end,
    },
    {
        name = "every class has a vendor, and every vendor has an opening-shelf item to sell",
        fn = function()
            for class in pairs(Item.CLASSES) do
                local vendorId
                for id, def in pairs(Vendor.defs) do
                    if def.class == class then vendorId = id end
                end
                assert(vendorId, "class '" .. class .. "' has no vendor")

                local entry = Vendor.stock(vendorId, 0)[1]
                assert(entry and not entry.locked,
                    vendorId .. " has nothing a new player can buy")
            end
        end,
    },
    {
        name = "every priced item has a shelf: a class vendor, or the general store",
        fn = function()
            -- The union of every general store's stock (the Cafe). A priced item with no class is
            -- not dead data any more -- it belongs to the general shelf. Built cafe-id-agnostically
            -- so this stays true if the general store is ever renamed or a second one is added.
            local generalStock = {}
            for vid, vdef in pairs(Vendor.defs) do
                if vdef.general then
                    for _, e in ipairs(Vendor.stock(vid, 999)) do generalStock[e.id] = true end
                end
            end

            for id, def in pairs(Item.defs) do
                if def.class then
                    assert(Item.CLASSES[def.class], id .. " has unknown class '" .. def.class .. "'")
                elseif def.price then
                    -- Priced but classless: a general good. Some general store must actually stock it,
                    -- or it is unbuyable dead data after all.
                    assert(generalStock[id], id .. " has a price but no class, and no general store stocks it")
                end
            end
        end,
    },
    {
        name = "the general store stocks classless goods and resells potions, gating nothing on standing",
        fn = function()
            local cafe = Vendor.stock("cafe", 1)
            assert(#cafe > 0, "the Cafe should stock something")

            local function hasTag(id, want)
                for _, tag in ipairs(Item.defs[id].tags or {}) do
                    if tag == want then return true end
                end
                return false
            end

            local ids = {}
            for _, entry in ipairs(cafe) do
                ids[entry.id] = true
                assert(entry.price, entry.id .. " is for sale with no price")
                -- Every ware is either a classless good or a potion resold from some house.
                assert(Item.defs[entry.id].class == nil or hasTag(entry.id, "potion"),
                    entry.id .. " is on the general shelf but is neither classless nor a potion")
                -- The Cafe keeps no ladder, so nothing it sells is ever rank-locked -- not even a
                -- Panacea, which needs rank 2 at the alchemist.
                assert(not entry.locked, entry.id .. " should never be standing-locked at the Cafe")
            end

            assert(ids.utility_torch, "the torch is a classless good the Cafe should sell")
            assert(ids.utility_boots_of_speed, "the boots of speed are classless and belong on the shelf")
            assert(ids.consumable_healing_potion, "the Cafe resells the healing potion")
            assert(ids.consumable_panacea, "a rank-2 alchemist potion is still un-gated at the Cafe")

            -- Reselling does not re-home: the potion keeps its class and still sells at the alchemist.
            assert(Item.defs.consumable_healing_potion.class == "alchemist",
                "the healing potion is still an alchemist item")
            local atAlchemist = false
            for _, entry in ipairs(Vendor.stock("alchemist", 4)) do
                if entry.id == "consumable_healing_potion" then atAlchemist = true end
            end
            assert(atAlchemist, "the alchemist still stocks the potions it brews")

            -- But the Cafe refines nothing: it resells potions, it does not hone their recipes.
            for _, entry in ipairs(cafe) do
                local sample = Item.instantiate(entry.id, nil, entry.level)
                assert(not Vendor.canRefineHere("cafe", sample),
                    entry.id .. " must not be refinable at the Cafe -- that stays at its house")
            end
        end,
    },
    {
        name = "class survives instantiation and is absent on universal items",
        fn = function()
            assert(Item.instantiate("weapon_iron_sword").class == "knight", "class should reach the instance")
            assert(Item.classOf(Item.instantiate("weapon_iron_sword")) == "knight", "classOf should read it")
            assert(Item.instantiate("weapon_unarmed").class == nil, "the unarmed fallback belongs to no class")
        end,
    },
    {
        name = "blueprints are untouched after Vendor.stock",
        fn = function()
            Vendor.stock("colosseum", 1)
            assert(Item.defs.weapon_iron_sword.locked == nil, "item blueprint gained a `locked` field")
            assert(Item.defs.weapon_iron_sword.id == nil, "item blueprint gained an `id` field")
        end,
    },

    -- ------------------------------------------------------------------ quest
    {
        name = "every sponsored quest names a vendor that exists, and only the finale is unsponsored",
        fn = function()
            for id, def in pairs(Quest.defs) do
                if def.sponsor then
                    assert(Vendor.defs[def.sponsor], id .. " names unknown sponsor " .. tostring(def.sponsor))
                else
                    -- Quest.available renders a sponsorless quest as "Unsponsored". Exactly one quest
                    -- earns that: no vendor sends you through the Gate Below -- all seven of them did.
                    assert(id == "quest_the_gate_below", id .. " has no sponsor")
                end
            end
        end,
    },
    {
        -- No shipped quest is `repeatable` (the game has no grind -- see models/quest.lua's header),
        -- so this only has the drop half to check, which is what it always actually checked.
        name = "Quest.available drops completed quests and opens the next slot",
        fn = function()
            local p = playerAt(1)

            local function boardHas(id)
                for _, q in ipairs(Quest.available(p)) do
                    if q.id == id then return true end
                end
                return false
            end

            assert(boardHas("quest_colosseum_slot_01"), "the debut is the prestige-1 board")
            assert(not boardHas("quest_colosseum_slot_02"), "slot 2 waits on slot 1")

            p.completedQuests.quest_colosseum_slot_01 = true
            assert(not boardHas("quest_colosseum_slot_01"), "a completed quest leaves the board")
            -- ...and the slot behind it arrives, which is the whole point of the chain: the debut is
            -- what opens the Colosseum's second card AND the Cathedral's first (docs/story.md).
            assert(boardHas("quest_colosseum_slot_02"), "clearing slot 1 opens slot 2")
            assert(boardHas("quest_cathedral_slot_01"), "the debut opens the Cathedral's line")
        end,
    },
    {
        name = "Quest.available hides a sponsor-quest-gated quest until enough of the house's quests are done",
        fn = function()
            local p = playerAt(5) -- prestige is not the gate here; the sponsor-quest count is
            -- slot 3 gates on requiredSponsorQuests = { cathedral, count = 3 } (and, in order, on slot 2).
            -- Put slots 1-2 behind it -- that clears the requiredQuests chain but leaves the Cathedral count
            -- at 2, one short of 3, which is what holds slot 3 back and is what this case is about.
            p.completedQuests.quest_colosseum_slot_01 = true -- a different house: must not count toward the Cathedral
            p.completedQuests.quest_cathedral_slot_01 = true
            p.completedQuests.quest_cathedral_slot_02 = true

            local function boardHas(id)
                for _, q in ipairs(Quest.available(p)) do
                    if q.id == id then return true end
                end
                return false
            end

            assert(not boardHas("quest_cathedral_slot_03"),
                "slot 3 needs 3 of the Cathedral's quests, and only 2 are done")

            p.completedQuests.quest_cathedral_the_twin_liturgy = true -- a 3rd Cathedral quest
            assert(boardHas("quest_cathedral_slot_03"),
                "slot 3 should appear once 3 of the Cathedral's quests are done")
        end,
    },
    {
        name = "Quest.available hides a quest until its sponsor's shop has opened",
        fn = function()
            local Building = require("models.building")
            -- quest_bastion_slot_01 heads the Bastion's line, sponsored by the Bastion, whose building
            -- does not open until prestige 2. A player at prestige 1 must not see it -- it would point
            -- at a locked door.
            assert(Quest.defs.quest_bastion_slot_01.sponsor == "bastion", "quest_bastion_slot_01 should be a Bastion quest")
            assert(Building.vendorUnlockPrestige("bastion") == 2, "the Bastion should open at prestige 2")

            local function boardHas(player, id)
                for _, q in ipairs(Quest.available(player)) do
                    if q.id == id then return true end
                end
                return false
            end

            assert(not boardHas(playerAt(1), "quest_bastion_slot_01"),
                "quest_bastion_slot_01 must stay hidden while the Bastion is still locked")
            assert(boardHas(playerAt(2), "quest_bastion_slot_01"),
                "quest_bastion_slot_01 should appear once the Bastion opens at prestige 2")
        end,
    },
    {
        name = "Quest.complete grants gold and prestige, and advances the sponsor's standing, exactly once",
        fn = function()
            local p = playerAt(1)
            p.gold = 0

            local quest
            for _, q in ipairs(Quest.available(p)) do
                if q.id == "quest_colosseum_slot_01" then quest = q end
            end
            assert(quest, "arena_debut should be available at prestige 1")

            local before = Quest.sponsorProgress(p, "colosseum")
            local reward = Quest.complete(p, quest)
            assert(reward, "completing a fresh quest should pay out")
            assert(p.gold == quest.rewardGold, "gold should be granted")
            assert(p.prestige == 1 + quest.rewardPrestige, "prestige should be granted")
            assert(Player.hasCompleted(p, "quest_colosseum_slot_01"), "the quest should be marked completed")
            assert(Quest.sponsorProgress(p, "colosseum") == before + 1,
                "finishing the quest is what advances the Colosseum's standing")
            assert(reward.sponsorQuests == before + 1, "the reward should report the sponsor's new quest count")

            -- A second payout is refused: the objective tile could otherwise be re-cleared.
            local gold, prestige = p.gold, p.prestige
            assert(Quest.complete(p, quest) == nil, "a completed quest must not pay twice")
            assert(p.gold == gold and p.prestige == prestige, "the refused payout must grant nothing")
        end,
    },

    -- ------------------------------------------------- the seven sins / the Gate Below
    {
        -- Quest.available copies blueprint fields ONE AT A TIME. A field the loop forgets reads nil
        -- at runtime and the gate silently opens (or the relic silently vanishes). Guard both.
        name = "Quest.available carries requiredQuests and rewardItems through the field copy",
        fn = function()
            local p = playerAt(10)
            p.completedQuests.quest_colosseum_slot_10 = true

            local gate, general
            for _, q in ipairs(Quest.available(p)) do
                if q.id == "quest_the_gate_below" then gate = q end
                if q.id == "quest_colosseum_slot_10" then general = q end
            end

            assert(gate, "the Gate should be on the board once one general is dead")
            assert(gate.requiredQuests and #gate.requiredQuests == 7,
                "the Gate must carry its seven prerequisites")

            -- general_wrath is completed above, so read rewardItems off the blueprint's own copy.
            assert(Quest.defs.quest_colosseum_slot_10.rewardItems[1] == "armor_mail_of_the_unappeased",
                "Ira should drop her mail")
            assert(general == nil, "and a completed, non-repeatable general leaves the board")
        end,
    },
    {
        name = "the Gate Below is hidden at zero keys, locked while short, and startable at seven",
        fn = function()
            local p = playerAt(10)

            local function gateEntry()
                for _, q in ipairs(Quest.available(p)) do
                    if q.id == "quest_the_gate_below" then return q end
                end
                return nil
            end

            assert(gateEntry() == nil, "with no generals dead, the Gate is not even rumoured")

            p.completedQuests.quest_colosseum_slot_10 = true
            local gate = gateEntry()
            assert(gate, "one key reveals it")
            assert(gate.locked, "but it cannot be entered")
            assert(gate.keysHeld == 1 and gate.keysNeeded == 7, "and it counts what is missing")

            p.completedQuests.quest_undercroft_slot_10 = true
            gate = gateEntry()
            assert(gate.keysHeld == 2 and gate.locked, "two of seven is still short")

            for _, id in ipairs(Quest.defs.quest_the_gate_below.requiredQuests) do
                p.completedQuests[id] = true
            end
            gate = gateEntry()
            assert(gate and not gate.locked, "seven keys open it")
            assert(gate.keysHeld == 7, "and the count is full")
        end,
    },
    {
        name = "a locked Gate recites only the hints of the generals already killed",
        fn = function()
            local p = playerAt(10)
            p.completedQuests.quest_colosseum_slot_10 = true

            local gate
            for _, q in ipairs(Quest.available(p)) do
                if q.id == "quest_the_gate_below" then gate = q end
            end

            assert(gate.hints and #gate.hints == 1, "one dead general gives up one fragment")
            assert(gate.hints[1] == Quest.defs.quest_colosseum_slot_10.gateHint,
                "and it is that general's own fragment")
        end,
    },
    {
        name = "prestige stays a HARD gate: holding a key does not excuse the Gate's prestige requirement",
        fn = function()
            local p = playerAt(1) -- the Gate wants prestige 10
            p.completedQuests.quest_colosseum_slot_10 = true

            for _, q in ipairs(Quest.available(p)) do
                assert(q.id ~= "quest_the_gate_below",
                    "holding a key does not excuse you from the prestige gate")
            end
        end,
    },
    {
        name = "Quest.complete grants a relic into the stash exactly once",
        fn = function()
            local p = playerAt(5)
            -- A general is slot 10 of a line that runs in order, so the nine in front of it have to be
            -- done. Its own gate wants ten Colosseum quests finished, so a capstone (the_fighting_cellar)
            -- rounds the count out past the nine slots -- exactly how a real playthrough reaches it.
            for _, id in ipairs({
                "quest_colosseum_slot_01", "quest_colosseum_slot_02", "quest_colosseum_slot_03", "quest_colosseum_slot_04",
                "quest_colosseum_slot_05", "quest_colosseum_slot_06", "quest_colosseum_slot_07", "quest_colosseum_slot_08",
                "quest_colosseum_slot_09", "quest_colosseum_the_fighting_cellar",
            }) do p.completedQuests[id] = true end

            local quest
            for _, q in ipairs(Quest.available(p)) do
                if q.id == "quest_colosseum_slot_10" then quest = q end
            end
            assert(quest, "at Legend with the line behind her, Ira should be on the board")

            local function stashCount(id)
                local n = 0
                for _, item in ipairs(p.stash) do
                    if item.id == id then n = n + 1 end
                end
                return n
            end
            assert(stashCount("armor_mail_of_the_unappeased") == 0, "the mail starts on Ira, not on you")

            local reward = Quest.complete(p, quest)
            assert(stashCount("armor_mail_of_the_unappeased") == 1, "killing her drops it into the stash")
            assert(reward.received and reward.received[1].id == "armor_mail_of_the_unappeased",
                "and the summary names what was received, for the reward panel")

            assert(Quest.complete(p, quest) == nil, "a second clear pays nothing")
            assert(stashCount("armor_mail_of_the_unappeased") == 1, "and mints no second relic")
        end,
    },
    {
        -- The relic is a trophy meant to be WORN. What opens the Gate is the quest you finished, so
        -- moving the mail onto a knight -- or losing it entirely -- can never soft-lock the endgame.
        name = "the Gate is keyed off the completed quest, not off holding the relic",
        fn = function()
            local p = playerAt(10)
            for _, id in ipairs(Quest.defs.quest_the_gate_below.requiredQuests) do
                p.completedQuests[id] = true
            end
            Player.grantItem(p, "armor_mail_of_the_unappeased")

            local function gateOpen()
                for _, q in ipairs(Quest.available(p)) do
                    if q.id == "quest_the_gate_below" then return not q.locked end
                end
                return false
            end
            assert(gateOpen(), "seven completed generals open the Gate")

            -- Wear it: it leaves the stash for a character's 3x3 grid.
            local mail = Player.takeFromStash(p, #p.stash)
            Character.addItem(p.roster[1], mail)
            assert(gateOpen(), "wearing the relic does not close the Gate")

            -- Lose it entirely.
            p.stash = {}
            p.roster[1].inventory = {}
            assert(gateOpen(), "nor does losing it")
        end,
    },
    {
        name = "Player.grantItem stacks a consumable rather than filling the stash with singles",
        fn = function()
            local p = Player.new()
            p.stash = {}
            Player.grantItem(p, "consumable_healing_potion")
            Player.grantItem(p, "consumable_healing_potion")
            assert(#p.stash == 1, "two potions collapse into one stack")
            assert(p.stash[1].quantity == 2, "and the stack counts both")
        end,
    },
    {
        name = "Quest.complete flags unlocked stock exactly when a completion crosses a tier threshold",
        fn = function()
            local p = playerAt(1)
            -- Two Colosseum quests done: count 2, still inside the opening tier (Vendor.TIERS = {0,3,6,10}).
            p.completedQuests.quest_colosseum_slot_01 = true
            p.completedQuests.quest_colosseum_slot_02 = true

            -- Completing a 3rd crosses into the next tier, so a fresh wave of stock lands on the shelf.
            local crossing = { id = "quest_colosseum_slot_03", sponsor = "colosseum",
                               rewardGold = 0, rewardPrestige = 0 }
            local reward = Quest.complete(p, crossing)
            assert(reward.unlockedStock == true, "the 3rd Colosseum quest crosses into the next stock tier")

            -- A 4th stays inside that tier (3 -> 4, both tier 2), so nothing new unlocks.
            local within = { id = "quest_colosseum_slot_04", sponsor = "colosseum",
                             rewardGold = 0, rewardPrestige = 0 }
            reward = Quest.complete(p, within)
            assert(reward.unlockedStock == false, "a completion inside the same tier unlocks nothing new")
        end,
    },

    -- ------------------------------------------------------------------- save
    {
        name = "a save round trip preserves gold, prestige and completed quests",
        fn = function()
            withScratchSave(function()
                local p = Player.new()
                p.gold = 777
                p.prestige = 4
                p.completedQuests.quest_colosseum_slot_01 = true

                assert(Save.write(p), "save should write")
                assert(Save.exists(), "the save file should exist")

                local loaded = Save.read()
                assert(loaded, "save should read back")
                assert(loaded.gold == 777, "gold should survive")
                assert(loaded.prestige == 4, "prestige should survive")
                assert(Player.hasCompleted(loaded, "quest_colosseum_slot_01"),
                    "completed quests should survive -- and with them the vendor standing they represent")
            end)
        end,
    },
    {
        name = "a save round trip preserves the roster, party identity, and each 3x3 grid cell",
        fn = function()
            withScratchSave(function()
                local p = Player.new()
                -- Park an item in a deliberately sparse cell: adjacency auras depend on placement,
                -- so the exact cell is gameplay state and must survive.
                local knight = p.roster[1]
                knight.inventory = {}
                knight.inventory[7] = Item.instantiate("consumable_fire_stone")

                Save.write(p)
                local loaded = Save.read()

                assert(#loaded.roster == #p.roster, "roster size should survive")
                assert(#loaded.party == #p.party, "party size should survive")
                assert(loaded.roster[1].id == "character_rowan", "roster order should survive")
                assert(loaded.roster[1].inventory[7], "the item should be back in cell 7")
                assert(loaded.roster[1].inventory[7].id == "consumable_fire_stone", "the right item should be in cell 7")
                assert(loaded.roster[1].inventory[1] == nil, "empty cells should stay empty")

                -- Party members are the same instances as their roster entries, not copies.
                assert(loaded.party[1] == loaded.roster[1], "party should reference the roster instance")
            end)
        end,
    },
    {
        name = "a save round trip preserves stash contents and consumable stack sizes",
        fn = function()
            withScratchSave(function()
                local p = Player.new()
                p.stash = {}
                Player.addToStash(p, Item.instantiate("consumable_healing_potion", 5))

                Save.write(p)
                local loaded = Save.read()

                assert(#loaded.stash == 1, "the stash should hold one entry")
                assert(loaded.stash[1].id == "consumable_healing_potion", "the potion should survive")
                assert(loaded.stash[1].quantity == 5, "the stack size should survive")
            end)
        end,
    },
    {
        name = "an unreadable or wrong-version save is discarded rather than half-loaded",
        fn = function()
            withScratchSave(function()
                love.filesystem.write(Save.FILE, "return { this is not lua")
                assert(Save.read() == nil, "a malformed save should read as nil")

                love.filesystem.write(Save.FILE, "return { version = 9999, gold = 1 }")
                assert(Save.read() == nil, "a future-version save should read as nil")
            end)
        end,
    },
    {
        name = "loading drops ids that no longer exist in data/ instead of crashing",
        fn = function()
            withScratchSave(function()
                local p = Player.new()
                Save.write(p)

                local snap = Save.snapshot(p)
                snap.stash[#snap.stash + 1] = { id = "item_that_was_deleted", quantity = 1 }
                snap.roster[#snap.roster + 1] = { id = "character_that_was_deleted", inventory = {} }

                local loaded = Save.restore(snap)
                assert(loaded, "the save should still restore")
                for _, item in ipairs(loaded.stash) do
                    assert(item.id ~= "item_that_was_deleted", "the unknown item should be dropped")
                end
                assert(#loaded.roster == #p.roster, "the unknown character should be dropped")
            end)
        end,
    },

    -- --------------------------------------------------- character progression (levels/growth)
    {
        name = "syncLevels catches every roster member up to prestige and reports who advanced",
        fn = function()
            local p = Player.new() -- roster at level 1, prestige 1
            p.prestige = 10

            -- Read the level off the curve rather than hardcoding it: prestige is NOT the level (several
            -- prestige buy one, and it caps), so a retune of Growth.PRESTIGE_PER_LEVEL should not turn
            -- this red. What is being asserted is that everyone catches up, not what the number is.
            local expected = Growth.levelForPrestige(p.prestige)
            assert(expected > 2, "the fixture must span more than one level for the climb to mean anything")

            -- A recruit added mid-campaign starts at level 1 and must be caught up too.
            local recruit = Character.instantiate("character_mage")
            p.roster[#p.roster + 1] = recruit
            assert(recruit.level == 1, "a fresh recruit starts at level 1")

            local summary = Player.syncLevels(p)
            assert(#summary == #p.roster, "every roster member advanced from level 1")
            for _, char in ipairs(p.roster) do
                assert(char.level == expected, char.name .. " should be caught up to level " .. expected)
            end

            -- Summary entries carry the shape the advancement overlay renders.
            local entry = summary[1]
            assert(entry.char and entry.fromLevel == 1 and entry.toLevel == expected, "summary spans the climb")
            assert(entry.class and next(entry.gains), "summary names the growth class and its gains")

            -- Already caught up: a second sync reports nothing.
            assert(#Player.syncLevels(p) == 0, "a re-sync at the same prestige advances no one")
        end,
    },
    {
        name = "Quest.complete folds the roster's advancement into its reward table",
        fn = function()
            -- Prestige 3, not 1, and that matters: a level costs several prestige now, so most quests
            -- grant prestige WITHOUT crossing a threshold and level nobody. (That is the ordinary case,
            -- and what the advancement bar exists to show.) This test is about the hand-off when a level
            -- DOES land, so the fixture is parked one prestige below the next one.
            local p = playerAt(3)
            local quest
            for _, q in ipairs(Quest.available(p)) do
                if q.id == "quest_colosseum_slot_01" then quest = q end
            end
            assert(quest and quest.rewardPrestige > 0, "arena_debut should grant prestige")
            assert(Growth.levelForPrestige(p.prestige + quest.rewardPrestige) > Growth.levelForPrestige(p.prestige),
                "the fixture must sit where this quest's prestige actually buys a level")

            -- The company as it stood when the prestige landed. arena_debut also carries a
            -- `rewardCharacter` (Saber is bested and kept), and she joins AFTER the level-ups are
            -- computed -- she did not earn this quest's prestige, and Player.recruit syncs her to the
            -- new level on the way in. So advancement covers the roster that fought, not the roster
            -- that walks home.
            local fought = #p.roster

            local reward = Quest.complete(p, quest)
            assert(reward.advancement, "the reward carries an advancement list")
            assert(#reward.advancement == fought, "prestige leveled the whole company")
            assert(reward.recruited and #p.roster == fought + 1,
                "and the bout's real reward joined on top of it")
        end,
    },
    {
        name = "a save round trip preserves level, class usage, and re-bakes accumulated growth",
        fn = function()
            withScratchSave(function()
                local p = Player.new()
                local knight = p.roster[1]
                -- `classUse` is the career tally behind the displayed title; `classUseSinceLevel` is
                -- the banked casts a level-up actually spends (models/growth.lua). Both are set, and
                -- both must survive the trip.
                knight.classUse = { mage = 12 }
                knight.classUseSinceLevel = { mage = 12 }
                -- Prestige 13, which is level 5 on the curve -- prestige is not the level (see
                -- Growth.levelForPrestige). Read back through the curve so a retune moves the fixture
                -- rather than breaking it.
                p.prestige = 13
                local expected = Growth.levelForPrestige(p.prestige)
                Player.syncLevels(p) -- knight climbs 1 -> `expected` as a mage; stats baked

                local grownMagic = knight.stats.magicDamage
                local grownHealthMax = knight.stats.health.max
                assert(knight.level == expected, "the knight reached level " .. expected)
                assert(grownMagic > Character.instantiate("character_rowan").stats.magicDamage,
                    "the mage growth actually raised magic")

                Save.write(p)
                local loaded = Save.read()
                assert(loaded, "the save should read back")

                local loadedKnight = loaded.roster[1]
                assert(loadedKnight.level == expected, "level should survive")
                assert(loadedKnight.classUse.mage == 12, "the class tally should survive")
                assert(loadedKnight.stats.magicDamage == grownMagic, "growth should re-bake onto magic")
                assert(loadedKnight.stats.health.max == grownHealthMax, "growth should re-bake onto the HP pool")
                assert(Growth.dominantClass(loadedKnight) == "mage", "the loaded knight still grows as a mage")
            end)
        end,
    },

    {
        -- The advancement overlay fills a bar from one prestige to the other, and that is the ONLY
        -- feedback most quests produce: a level costs several prestige while a quest pays one or two,
        -- so a quest that levels nobody is the ordinary case, not an edge case. If this pair ever stops
        -- riding out on the reward, half of all quests silently go back to reporting nothing.
        name = "Quest.complete reports the prestige step, even when nobody levels",
        fn = function()
            local p = playerAt(1)
            local quest
            for _, q in ipairs(Quest.available(p)) do
                if q.id == "quest_colosseum_slot_01" then quest = q end
            end
            assert(quest, "the fixture quest should be available")

            local before = p.prestige
            local reward = Quest.complete(p, quest)

            assert(reward.prestigeBefore == before, "the step starts where the company stood")
            assert(reward.prestigeAfter == p.prestige, "and ends where it now stands")
            assert(reward.prestigeAfter > reward.prestigeBefore, "and actually moved")

            -- This particular quest pays too little to cross a threshold from prestige 1 -- which is
            -- exactly the case the bar exists for, so assert it rather than assume it.
            assert(Growth.levelForPrestige(reward.prestigeAfter)
                == Growth.levelForPrestige(reward.prestigeBefore),
                "fixture check: this quest is meant NOT to level anyone")
            assert(#(reward.advancement or {}) == 0, "so no one levelled...")
            assert(Growth.prestigeIntoLevel(reward.prestigeAfter)
                > Growth.prestigeIntoLevel(reward.prestigeBefore),
                "...but the bar has visibly moved, which is the whole point")
        end,
    },

    {
        -- Every save written before per-class level crediting existed has no `growthBy`. Such a save
        -- must not read as a character that never levelled -- and it must not have its stats recomputed
        -- either, since the deltas it stores were earned under the old winner-takes-all rule.
        name = "a save from before the per-class ledger loads with its history seeded, not lost",
        fn = function()
            local live = Character.instantiate("character_rowan")
            live.classUse = { mage = 30 }
            live.classUseSinceLevel = { mage = 30 }
            Growth.resolve(live, 6)

            -- The same character as an OLD save would have stored it: level, tally and baked deltas,
            -- but no ledger at all.
            local legacy = {
                id = live.id,
                level = live.level,
                classUse = { mage = 30 },
                growth = live.growth,
            }
            assert(legacy.growthBy == nil, "the fixture must actually be a pre-ledger save")

            local loaded = Save.restoreCharacter(legacy)

            assert(loaded.level == live.level, "the level survives")
            assert(loaded.stats.magicDamage == live.stats.magicDamage,
                "and the stats are the ones that save had, re-baked rather than recomputed")
            assert(loaded.stats.health.max == live.stats.health.max, "pools too")

            -- The ledger is seeded the way those stats were actually earned: under the old rule the
            -- whole climb went to the one dominant class.
            assert(loaded.growthBy and loaded.growthBy.mage == live.level - 1, string.format(
                "expected the climb credited to mage, got %s",
                loaded.growthBy and loaded.growthBy.mage or "nothing"))

            -- A current save is never rewritten by that seed.
            local current = Save.restoreCharacter({
                id = live.id, level = 4, classUse = { mage = 30 }, growthBy = { knight = 3 },
            })
            assert(current.growthBy.knight == 3 and current.growthBy.mage == nil,
                "a save that carries a ledger keeps exactly the one it carries")
        end,
    },

    -- ---------------------------------------------------------------- protect
    {
        name = "a protect objective loses the battle the moment the charge falls",
        fn = function()
            local objective = { type = "killAll", protect = "character_caravan_master" }
            local c = Combat.new(arena(8, 8, objective),
                { unit("character_rowan", 3, 6), unit("character_caravan_master", 4, 6, "ai") },
                { unit("character_bandit", 4, 1) })

            assert(Combat.evaluate(c) == nil, "the battle is undecided while everyone stands")

            local escortee = c.units[2]
            assert(escortee.char.id == "character_caravan_master", "the escortee should be unit 2")
            escortee.alive = false
            assert(Combat.evaluate(c) == "loss", "losing the charge should lose the battle")
        end,
    },
    {
        name = "protect does not block the win when the charge survives",
        fn = function()
            local objective = { type = "killAll", protect = "character_caravan_master" }
            local c = Combat.new(arena(8, 8, objective),
                { unit("character_rowan", 3, 6), unit("character_caravan_master", 4, 6, "ai") },
                { unit("character_bandit", 4, 1) })

            c.units[3].alive = false -- the last enemy falls
            assert(Combat.evaluate(c) == "win", "killAll should still resolve with the charge alive")
        end,
    },
    {
        name = "an escorted ally fights on the party's side but is not player-controlled",
        fn = function()
            local c = Combat.new(arena(8, 8),
                { unit("character_rowan", 3, 6), unit("character_caravan_master", 4, 6, "ai") },
                { unit("character_bandit", 4, 1) })

            local knight, escortee = c.units[1], c.units[2]
            assert(Combat.isPlayerControlled(knight), "the knight takes an interactive turn")
            assert(not Combat.isPlayerControlled(escortee), "the escortee runs itself")
            assert(escortee.side == "party", "the escortee is on the party's side")

            -- The AI plans against the *other* side, so an escort never turns on its escort.
            local plan = Combat.planEnemyAction(c, escortee)
            assert(plan, "the escortee should produce a plan")
            if plan.item and plan.tx then
                local target = Combat.unitAt(c, plan.tx, plan.ty)
                assert(not target or target.side == "enemy", "the escortee must not attack the party")
            end
        end,
    },
    {
        name = "Arena.build spawns escorted allies on party tiles, after the party itself",
        fn = function()
            local built = Arena.build({ prestige = 1 }, {
                biome = "forest",
                party = { "character_rowan", "character_mage" },
                allies = { "character_caravan_master" },
                composition = { "character_bandit" },
                objective = { type = "killAll", protect = "character_caravan_master" },
                seed = 4242,
            })

            assert(#built.party == 2, "both party members should spawn")
            assert(#built.allies == 1, "the escortee should spawn")
            assert(built.allies[1].id == "character_caravan_master", "the escortee should be the caravan master")

            -- Nobody shares a tile.
            local seen = {}
            for _, u in ipairs({ built.party[1], built.party[2], built.allies[1] }) do
                local k = u.x .. "," .. u.y
                assert(not seen[k], "two units spawned on the same tile")
                seen[k] = true
            end
        end,
    },
    {
        name = "a build with no allies has an empty ally list, not a default foe",
        fn = function()
            -- Arena.resolveComposition defaults a nil composition to a lone bandit; allies must
            -- not inherit that fallback or every battle would gain a stray ally.
            local built = Arena.build({ prestige = 1 }, {
                biome = "forest", party = { "character_rowan" }, composition = { "character_bandit" }, seed = 7,
            })
            assert(#built.allies == 0, "no allies were asked for, so none should spawn")
        end,
    },
}
