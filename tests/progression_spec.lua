-- Tests for the progression layer: the save round trip, the gold/prestige/reputation
-- economy, vendor stock derivation and rank gating, quest sponsorship and completion, and
-- the composable `protect` objective.
--
-- The save specs write to a throwaway filename so a developer's real save is never touched.

local Player = require("models.player")
local Vendor = require("models.vendor")
local Quest = require("models.quest")
local Item = require("models.item")
local Save = require("models.save")
local Character = require("models.character")
local Combat = require("models.combat")
local Arena = require("models.arena")

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
        name = "reputation with an unknown vendor reads as zero rather than nil",
        fn = function()
            local p = Player.new()
            assert(Player.reputation(p, "colosseum") == 0, "unseen vendor should read 0")
            Player.addReputation(p, "colosseum", 15)
            assert(Player.reputation(p, "colosseum") == 15, "reputation should accumulate")
        end,
    },
    {
        name = "repRank resolves exactly at each threshold boundary",
        fn = function()
            local ranks = Vendor.defs.colosseum.ranks -- { 0, 40, 100, 200 }
            local p = Player.new()

            -- One point below a threshold is still the lower rank; landing on it promotes.
            for i = 2, #ranks do
                p.reputation.colosseum = ranks[i] - 1
                assert(Player.repRank(p, "colosseum") == i - 1,
                    "one short of threshold " .. i .. " should stay at rank " .. (i - 1))
                p.reputation.colosseum = ranks[i]
                assert(Player.repRank(p, "colosseum") == i,
                    "hitting threshold " .. i .. " should promote to rank " .. i)
            end

            -- Rank never exceeds the top of the ladder, however much reputation piles up.
            p.reputation.colosseum = 99999
            assert(Player.repRank(p, "colosseum") == #ranks, "rank should cap at the top rung")
        end,
    },
    {
        name = "nextRank counts down to the next rung, and reports nil at the top",
        fn = function()
            local toNext, rank = Vendor.nextRank("colosseum", 30)
            assert(toNext == 10, "30 rep is 10 short of the 40 threshold")
            assert(rank == 2, "the next rung is rank 2")
            assert(Vendor.nextRank("colosseum", 200) == nil, "max standing has no next rung")
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
                assert(def.ranks[1] == 0, id .. " entry rank must be 0")
                assert(#def.ranks == #def.rankNames, id .. " has a rank without a name")
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
                assert(Item.defs[entry.id].class == "rogue",
                    entry.id .. " is on the rogue shelf without being a rogue item")
                assert(entry.price, entry.id .. " is for sale with no price")
            end

            assert(ids.ability_pickpocket, "pickpocket should be a rogue item")
            assert(not ids.iron_sword, "the iron sword is a fighter item, not a rogue one")
        end,
    },
    {
        name = "Vendor.stock shows rank-locked items, flagged rather than hidden",
        fn = function()
            local low = Vendor.stock("colosseum", 1)
            local high = Vendor.stock("colosseum", 4)
            assert(#low == #high, "the shelf is the same length at every rank")

            local lockedAtLow, lockedAtHigh = 0, 0
            for _, e in ipairs(low) do if e.locked then lockedAtLow = lockedAtLow + 1 end end
            for _, e in ipairs(high) do if e.locked then lockedAtHigh = lockedAtHigh + 1 end end

            assert(lockedAtLow > 0, "a rank-1 player should see items they cannot buy yet")
            assert(lockedAtHigh == 0, "a top-rank player should have everything unlocked")
        end,
    },
    {
        name = "every class has a vendor, and every vendor has a rank-1 item to sell",
        fn = function()
            for class in pairs(Item.CLASSES) do
                local vendorId
                for id, def in pairs(Vendor.defs) do
                    if def.class == class then vendorId = id end
                end
                assert(vendorId, "class '" .. class .. "' has no vendor")

                local entry = Vendor.stock(vendorId, 1)[1]
                assert(entry and not entry.locked,
                    vendorId .. " has nothing a new player can buy")
            end
        end,
    },
    {
        name = "every item names a known class, or none at all",
        fn = function()
            for id, def in pairs(Item.defs) do
                if def.class then
                    assert(Item.CLASSES[def.class], id .. " has unknown class '" .. def.class .. "'")
                end
                -- A priced item nobody stocks would be unbuyable dead data.
                if def.price then assert(def.class, id .. " has a price but no class to sell it") end
            end
        end,
    },
    {
        name = "class survives instantiation and is absent on universal items",
        fn = function()
            assert(Item.instantiate("iron_sword").class == "fighter", "class should reach the instance")
            assert(Item.classOf(Item.instantiate("iron_sword")) == "fighter", "classOf should read it")
            assert(Item.instantiate("unarmed").class == nil, "the unarmed fallback belongs to no class")
        end,
    },
    {
        name = "blueprints are untouched after Vendor.stock",
        fn = function()
            Vendor.stock("colosseum", 1)
            assert(Item.defs.iron_sword.locked == nil, "item blueprint gained a `locked` field")
            assert(Item.defs.iron_sword.id == nil, "item blueprint gained an `id` field")
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
                    assert(id == "the_gate_below", id .. " has no sponsor")
                end
            end
        end,
    },
    {
        name = "Quest.available drops completed quests, but keeps repeatable ones",
        fn = function()
            local p = playerAt(1)

            local before = #Quest.available(p)
            assert(before > 0, "a new player should have quests")

            p.completedQuests.arena_debut = true
            local after = Quest.available(p)
            assert(#after == before - 1, "a completed quest should leave the board")
            for _, q in ipairs(after) do
                assert(q.id ~= "arena_debut", "arena_debut should be gone")
            end
        end,
    },
    {
        name = "Quest.available hides a reputation-gated quest until the rank is earned",
        fn = function()
            local p = playerAt(5) -- prestige is not the gate here; reputation is

            local function boardHas(id)
                for _, q in ipairs(Quest.available(p)) do
                    if q.id == id then return true end
                end
                return false
            end

            assert(not boardHas("rite_of_ashes"), "rite_of_ashes needs Cathedral rank 2")

            Player.addReputation(p, "cathedral", Vendor.defs.cathedral.ranks[2])
            assert(boardHas("rite_of_ashes"), "rite_of_ashes should appear at Cathedral rank 2")
        end,
    },
    {
        name = "Quest.complete grants gold, prestige and sponsor reputation exactly once",
        fn = function()
            local p = playerAt(1)
            p.gold = 0

            local quest
            for _, q in ipairs(Quest.available(p)) do
                if q.id == "arena_debut" then quest = q end
            end
            assert(quest, "arena_debut should be available at prestige 1")

            local reward = Quest.complete(p, quest)
            assert(reward, "completing a fresh quest should pay out")
            assert(p.gold == quest.rewardGold, "gold should be granted")
            assert(p.prestige == 1 + quest.rewardPrestige, "prestige should be granted")
            assert(Player.reputation(p, "colosseum") == quest.rewardRep, "sponsor reputation should be granted")
            assert(Player.hasCompleted(p, "arena_debut"), "the quest should be marked completed")

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
            p.completedQuests.general_wrath = true

            local gate, general
            for _, q in ipairs(Quest.available(p)) do
                if q.id == "the_gate_below" then gate = q end
                if q.id == "general_wrath" then general = q end
            end

            assert(gate, "the Gate should be on the board once one general is dead")
            assert(gate.requiredQuests and #gate.requiredQuests == 7,
                "the Gate must carry its seven prerequisites")

            -- general_wrath is completed above, so read rewardItems off the blueprint's own copy.
            assert(Quest.defs.general_wrath.rewardItems[1] == "mail_of_the_unappeased",
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
                    if q.id == "the_gate_below" then return q end
                end
                return nil
            end

            assert(gateEntry() == nil, "with no generals dead, the Gate is not even rumoured")

            p.completedQuests.general_wrath = true
            local gate = gateEntry()
            assert(gate, "one key reveals it")
            assert(gate.locked, "but it cannot be entered")
            assert(gate.keysHeld == 1 and gate.keysNeeded == 7, "and it counts what is missing")

            p.completedQuests.general_greed = true
            gate = gateEntry()
            assert(gate.keysHeld == 2 and gate.locked, "two of seven is still short")

            for _, id in ipairs(Quest.defs.the_gate_below.requiredQuests) do
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
            p.completedQuests.general_wrath = true

            local gate
            for _, q in ipairs(Quest.available(p)) do
                if q.id == "the_gate_below" then gate = q end
            end

            assert(gate.hints and #gate.hints == 1, "one dead general gives up one fragment")
            assert(gate.hints[1] == Quest.defs.general_wrath.gateHint,
                "and it is that general's own fragment")
        end,
    },
    {
        name = "prestige and reputation stay HARD gates: a locked quest still needs the standing",
        fn = function()
            local p = playerAt(1) -- the Gate wants prestige 10
            p.completedQuests.general_wrath = true

            for _, q in ipairs(Quest.available(p)) do
                assert(q.id ~= "the_gate_below",
                    "holding a key does not excuse you from the prestige gate")
            end
        end,
    },
    {
        name = "Quest.complete grants a relic into the stash exactly once",
        fn = function()
            local p = playerAt(5)
            Player.addReputation(p, "colosseum", Vendor.defs.colosseum.ranks[4])

            local quest
            for _, q in ipairs(Quest.available(p)) do
                if q.id == "general_wrath" then quest = q end
            end
            assert(quest, "at Legend and prestige 5, Ira should be on the board")

            local function stashCount(id)
                local n = 0
                for _, item in ipairs(p.stash) do
                    if item.id == id then n = n + 1 end
                end
                return n
            end
            assert(stashCount("mail_of_the_unappeased") == 0, "the mail starts on Ira, not on you")

            local reward = Quest.complete(p, quest)
            assert(stashCount("mail_of_the_unappeased") == 1, "killing her drops it into the stash")
            assert(reward.received and reward.received[1].id == "mail_of_the_unappeased",
                "and the summary names what was received, for the reward panel")

            assert(Quest.complete(p, quest) == nil, "a second clear pays nothing")
            assert(stashCount("mail_of_the_unappeased") == 1, "and mints no second relic")
        end,
    },
    {
        -- The relic is a trophy meant to be WORN. What opens the Gate is the quest you finished, so
        -- moving the mail onto a knight -- or losing it entirely -- can never soft-lock the endgame.
        name = "the Gate is keyed off the completed quest, not off holding the relic",
        fn = function()
            local p = playerAt(10)
            for _, id in ipairs(Quest.defs.the_gate_below.requiredQuests) do
                p.completedQuests[id] = true
            end
            Player.grantItem(p, "mail_of_the_unappeased")

            local function gateOpen()
                for _, q in ipairs(Quest.available(p)) do
                    if q.id == "the_gate_below" then return not q.locked end
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
            Player.grantItem(p, "healing_potion")
            Player.grantItem(p, "healing_potion")
            assert(#p.stash == 1, "two potions collapse into one stack")
            assert(p.stash[1].quantity == 2, "and the stack counts both")
        end,
    },
    {
        name = "Quest.complete reports a rank-up exactly when one crosses a threshold",
        fn = function()
            local p = playerAt(1)
            local quest = { id = "spec_quest", sponsor = "colosseum", rewardGold = 0,
                            rewardPrestige = 0, rewardRep = 25 }

            local reward = Quest.complete(p, quest)
            assert(reward.rankedUp == false, "25 rep is short of the rank-2 threshold of 40")

            p.completedQuests.spec_quest = nil -- allow a second payout for the spec
            reward = Quest.complete(p, quest)
            assert(reward.rankedUp == true, "50 rep should cross into rank 2")
            assert(reward.rankName == Vendor.rankName("colosseum", 2), "the new rank should be named")
        end,
    },

    -- ------------------------------------------------------------------- save
    {
        name = "a save round trip preserves gold, prestige, reputation and completed quests",
        fn = function()
            withScratchSave(function()
                local p = Player.new()
                p.gold = 777
                p.prestige = 4
                Player.addReputation(p, "arcanum", 65)
                p.completedQuests.arena_debut = true

                assert(Save.write(p), "save should write")
                assert(Save.exists(), "the save file should exist")

                local loaded = Save.read()
                assert(loaded, "save should read back")
                assert(loaded.gold == 777, "gold should survive")
                assert(loaded.prestige == 4, "prestige should survive")
                assert(Player.reputation(loaded, "arcanum") == 65, "reputation should survive")
                assert(Player.hasCompleted(loaded, "arena_debut"), "completed quests should survive")
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
                knight.inventory[7] = Item.instantiate("fire_stone")

                Save.write(p)
                local loaded = Save.read()

                assert(#loaded.roster == #p.roster, "roster size should survive")
                assert(#loaded.party == #p.party, "party size should survive")
                assert(loaded.roster[1].id == "knight", "roster order should survive")
                assert(loaded.roster[1].inventory[7], "the item should be back in cell 7")
                assert(loaded.roster[1].inventory[7].id == "fire_stone", "the right item should be in cell 7")
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
                Player.addToStash(p, Item.instantiate("healing_potion", 5))

                Save.write(p)
                local loaded = Save.read()

                assert(#loaded.stash == 1, "the stash should hold one entry")
                assert(loaded.stash[1].id == "healing_potion", "the potion should survive")
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

    -- ---------------------------------------------------------------- protect
    {
        name = "a protect objective loses the battle the moment the charge falls",
        fn = function()
            local objective = { type = "killAll", protect = "caravan_master" }
            local c = Combat.new(arena(8, 8, objective),
                { unit("knight", 3, 6), unit("caravan_master", 4, 6, "ai") },
                { unit("bandit", 4, 1) })

            assert(Combat.evaluate(c) == nil, "the battle is undecided while everyone stands")

            local escortee = c.units[2]
            assert(escortee.char.id == "caravan_master", "the escortee should be unit 2")
            escortee.alive = false
            assert(Combat.evaluate(c) == "loss", "losing the charge should lose the battle")
        end,
    },
    {
        name = "protect does not block the win when the charge survives",
        fn = function()
            local objective = { type = "killAll", protect = "caravan_master" }
            local c = Combat.new(arena(8, 8, objective),
                { unit("knight", 3, 6), unit("caravan_master", 4, 6, "ai") },
                { unit("bandit", 4, 1) })

            c.units[3].alive = false -- the last enemy falls
            assert(Combat.evaluate(c) == "win", "killAll should still resolve with the charge alive")
        end,
    },
    {
        name = "an escorted ally fights on the party's side but is not player-controlled",
        fn = function()
            local c = Combat.new(arena(8, 8),
                { unit("knight", 3, 6), unit("caravan_master", 4, 6, "ai") },
                { unit("bandit", 4, 1) })

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
                party = { "knight", "mage" },
                allies = { "caravan_master" },
                composition = { "bandit" },
                objective = { type = "killAll", protect = "caravan_master" },
                seed = 4242,
            })

            assert(#built.party == 2, "both party members should spawn")
            assert(#built.allies == 1, "the escortee should spawn")
            assert(built.allies[1].id == "caravan_master", "the escortee should be the caravan master")

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
                biome = "forest", party = { "knight" }, composition = { "bandit" }, seed = 7,
            })
            assert(#built.allies == 0, "no allies were asked for, so none should spawn")
        end,
    },
}
