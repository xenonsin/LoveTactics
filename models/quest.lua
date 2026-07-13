-- Quest logic. Blueprints live in data/quests/<id>.lua. `Quest.available` returns the
-- quests a player may currently take, as fresh copies so the board can be sorted/mutated
-- without touching the blueprints.
--
-- Every quest names a `sponsor` (a vendor id). Completing it pays gold, prestige, and
-- reputation with that sponsor, which unlocks more of the sponsor's shelf. That loop --
-- pick a quest by who sponsors it, run it, spend the standing it earned -- is the game.

local Registry = require("models.registry")
local Player = require("models.player")
local Vendor = require("models.vendor")

local Quest = {}

Quest.defs = Registry.load("data/quests", "data.quests")

-- Does the player meet a quest's reputation gate? `requiredRep = { vendor = id, rank = n }`
-- keeps a sponsor's later quests off the board until you have earned their trust.
local function meetsRepGate(player, def)
    local gate = def.requiredRep
    if not gate then return true end
    return Player.repRank(player, gate.vendor) >= gate.rank
end

-- Does the player hold every quest this one names as a prerequisite? `requiredQuests` is a list of
-- quest ids, ALL of which must be complete -- the seven generals standing between the player and the
-- Gate Below.
--
-- Returns (met, have, need), because unlike the other two gates this one is worth SHOWING rather than
-- hiding: a player two keys short of the Gate should see that they are two keys short. Quest.available
-- surfaces it as a `locked` entry.
local function questGate(player, def)
    local req = def.requiredQuests
    if not req then return true, 0, 0 end

    local have = 0
    for _, questId in ipairs(req) do
        if Player.hasCompleted(player, questId) then have = have + 1 end
    end
    return have == #req, have, #req
end

-- The location hints earned so far: each prerequisite quest may name one fragment (`gateHint`), and
-- the fragments only appear as their quests are finished. Seven fragments name the place.
--
-- Derived, never stored. The relic a general drops carries the same words in its description, but the
-- hint the board shows is keyed off the quest you completed -- so selling, moving, or losing the relic
-- can never cost you the hint, nor the key it stands for.
local function gateHints(player, def)
    local hints = {}
    for _, questId in ipairs(def.requiredQuests or {}) do
        local prereq = Quest.defs[questId]
        if prereq and prereq.gateHint and Player.hasCompleted(player, questId) then
            hints[#hints + 1] = prereq.gateHint
        end
    end
    return hints
end

-- The quests this player may see: prestige met, reputation gate met, and not already completed
-- (unless the quest is `repeatable` -- grind quests that keep a sponsor's reputation climbing after
-- their story line is spent).
--
-- Prestige and reputation are HARD gates: fail one and the quest is not on the board at all. A
-- `requiredQuests` gate is SOFT: once the player holds at least one of the prerequisites, the quest
-- appears `locked`, carrying its key count and the hints earned so far. Seeing what you have not yet
-- earned is the point of a ladder -- the same reason Vendor.stock returns rank-locked items flagged
-- rather than hidden. The caller must refuse to start a locked quest (see ui/panels/quest_board.lua).
function Quest.available(player)
    local prestige = player.prestige or 1

    local list = {}
    for id, def in pairs(Quest.defs) do
        local unlocked = prestige >= (def.requiredPrestige or 1) and meetsRepGate(player, def)
        local exhausted = Player.hasCompleted(player, id) and not def.repeatable
        local questsMet, keysHeld, keysNeeded = questGate(player, def)
        local locked = not questsMet

        if unlocked and not exhausted and (questsMet or keysHeld >= 1) then
            local sponsor = def.sponsor and Vendor.get(def.sponsor)
            list[#list + 1] = {
                id = id,
                name = def.name,
                description = def.description,
                difficulty = def.difficulty,
                rewardGold = def.rewardGold,
                rewardRep = def.rewardRep or 0,
                rewardPrestige = def.rewardPrestige or 0,
                rewardItems = def.rewardItems, -- item ids granted on completion (a general's relic)
                sponsor = def.sponsor,
                sponsorName = sponsor and sponsor.name or "Unsponsored",
                repeatable = def.repeatable,
                requiredPrestige = def.requiredPrestige or 1,
                requiredQuests = def.requiredQuests,
                -- Locked entries are shown, not started. keysHeld/keysNeeded drive the board's
                -- "3 of 7 keys"; hints are the fragments the finished prerequisites gave up.
                locked = locked,
                keysHeld = keysHeld,
                keysNeeded = keysNeeded,
                hints = locked and gateHints(player, def) or nil,
                map = def.map, -- overworld generation params; see models/overworld.lua
            }
        end
    end

    table.sort(list, function(a, b)
        if a.requiredPrestige ~= b.requiredPrestige then
            return a.requiredPrestige < b.requiredPrestige
        end
        return a.name < b.name
    end)
    return list
end

-- Pay out a finished quest and persist. Called once, from the objective-win branch in
-- states/game.lua. Returns a summary the UI can show, or nil if the quest was already
-- completed and is not repeatable (a guard against double payout).
function Quest.complete(player, quest)
    if Player.hasCompleted(player, quest.id) and not quest.repeatable then
        return nil
    end

    local gold = quest.rewardGold or 0
    local prestige = quest.rewardPrestige or 0
    local rep = quest.rewardRep or 0

    Player.addGold(player, gold)
    -- Prestige raises every roster member's level; the returned summary (who advanced, and their stat
    -- gains from their most-used class) rides out in the reward table for the advancement overlay.
    local advancement = Player.addPrestige(player, prestige)

    local rankBefore
    if quest.sponsor and rep > 0 then
        rankBefore = Player.repRank(player, quest.sponsor)
        Player.addReputation(player, quest.sponsor, rep)
    end

    player.completedQuests = player.completedQuests or {}
    player.completedQuests[quest.id] = true

    -- Item rewards: a general's relic, granted into the stash. Guarded by the double-payout check at
    -- the top of this function, so a re-cleared objective tile can never mint a second one. Note the
    -- relic is a TROPHY, not a key -- what opens the Gate Below is the line above, the completed
    -- quest itself (see questGate), which no amount of moving the item around can undo.
    local received = {}
    for _, itemId in ipairs(quest.rewardItems or {}) do
        received[#received + 1] = Player.grantItem(player, itemId)
    end

    -- Forging materials: `rewardMaterials = { steel_ingot = 3 }` accrues into the player's stock
    -- (models/material.lua), the raw metal the Blacksmith spends on upgrades. Guarded by the same
    -- double-payout check at the top, so a re-cleared tile can't mint a second haul.
    local materials = {}
    for matId, count in pairs(quest.rewardMaterials or {}) do
        Player.addMaterial(player, matId, count)
        materials[matId] = count
    end

    Player.save()

    local rankAfter = quest.sponsor and Player.repRank(player, quest.sponsor)
    return {
        gold = gold,
        prestige = prestige,
        rep = rep,
        received = received, -- item instances, for the reward panel to name
        materials = materials, -- { id = count } granted, for the reward panel to name
        advancement = advancement, -- roster members that leveled up, for the advancement overlay
        sponsor = quest.sponsor,
        -- True when this quest pushed the player up a rank -- the moment new stock appears
        -- on the sponsor's shelf, and the thing worth announcing.
        rankedUp = rankBefore ~= nil and rankAfter > rankBefore,
        rankName = quest.sponsor and Vendor.rankName(quest.sponsor, rankAfter or 1),
    }
end

return Quest
