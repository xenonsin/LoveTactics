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

-- The quests this player may take: prestige met, reputation gate met, and not already
-- completed (unless the quest is `repeatable` -- grind quests that keep a sponsor's
-- reputation climbing after their story line is spent).
function Quest.available(player)
    local prestige = player.prestige or 1

    local list = {}
    for id, def in pairs(Quest.defs) do
        local unlocked = prestige >= (def.requiredPrestige or 1) and meetsRepGate(player, def)
        local exhausted = Player.hasCompleted(player, id) and not def.repeatable

        if unlocked and not exhausted then
            local sponsor = def.sponsor and Vendor.get(def.sponsor)
            list[#list + 1] = {
                id = id,
                name = def.name,
                description = def.description,
                difficulty = def.difficulty,
                rewardGold = def.rewardGold,
                rewardRep = def.rewardRep or 0,
                rewardPrestige = def.rewardPrestige or 0,
                sponsor = def.sponsor,
                sponsorName = sponsor and sponsor.name or "Unsponsored",
                repeatable = def.repeatable,
                requiredPrestige = def.requiredPrestige or 1,
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
    Player.addPrestige(player, prestige)

    local rankBefore
    if quest.sponsor and rep > 0 then
        rankBefore = Player.repRank(player, quest.sponsor)
        Player.addReputation(player, quest.sponsor, rep)
    end

    player.completedQuests = player.completedQuests or {}
    player.completedQuests[quest.id] = true
    Player.save()

    local rankAfter = quest.sponsor and Player.repRank(player, quest.sponsor)
    return {
        gold = gold,
        prestige = prestige,
        rep = rep,
        sponsor = quest.sponsor,
        -- True when this quest pushed the player up a rank -- the moment new stock appears
        -- on the sponsor's shelf, and the thing worth announcing.
        rankedUp = rankBefore ~= nil and rankAfter > rankBefore,
        rankName = quest.sponsor and Vendor.rankName(quest.sponsor, rankAfter or 1),
    }
end

return Quest
