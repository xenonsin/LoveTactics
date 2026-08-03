-- Quest logic. Blueprints live in data/quests/<id>.lua. `Quest.available` returns the
-- quests a player may currently take, as fresh copies so the board can be sorted/mutated
-- without touching the blueprints.
--
-- Every quest names a `sponsor` (a vendor id). Completing it pays gold and prestige, and
-- -- because a vendor's standing simply IS how many of its quests you have finished
-- (Quest.sponsorProgress) -- unlocks more of that sponsor's shelf. That loop -- pick a quest
-- by who sponsors it, run it, then spend at the shelf the finished quest just opened -- is the game.

local Registry = require("models.registry")
local Player = require("models.player")
local Vendor = require("models.vendor")
local Building = require("models.building")
local Debug = require("models.debug")

local Quest = {}

Quest.defs = Registry.load("data/quests", "data.quests")

-- How many of vendor `vendorId`'s quests this player has finished. This IS the player's standing
-- with that house: the shelf opens (Vendor.stock) and the ability bench's cap climbs
-- (Vendor.abilityLevelCap) as this number grows. Counts every completed quest whose blueprint names
-- the vendor as `sponsor` -- so it survives selling a relic or losing a save's reputation field, which
-- no longer exists.
function Quest.sponsorProgress(player, vendorId)
    if not vendorId then return 0 end
    local done = 0
    for id in pairs(player.completedQuests or {}) do
        local def = Quest.defs[id]
        if def and def.sponsor == vendorId then done = done + 1 end
    end
    return done
end

-- Does the player meet a quest's sponsor-quest gate? `requiredSponsorQuests = { vendor = id, count = n }`
-- keeps a sponsor's later quests off the board until you have finished enough of that sponsor's earlier
-- ones -- the same quest count the shelf gates on.
local function meetsSponsorQuestGate(player, def)
    local gate = def.requiredSponsorQuests
    if not gate then return true end
    return Quest.sponsorProgress(player, gate.vendor) >= gate.count
end

-- Is the quest's sponsoring vendor open yet? A vendor's shop opens with its building
-- (Building.vendorUnlockPrestige), and a sponsor's quests must not appear before you can
-- walk into the shop that pays for them -- a bastion quest at prestige 1 would point at a
-- door still locked until prestige 2. Unsponsored quests (the Gate Below) are never gated.
local function meetsSponsorGate(player, def)
    if not def.sponsor then return true end
    return (player.prestige or 1) >= Building.vendorUnlockPrestige(def.sponsor)
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

-- The quests this player may see: prestige met, sponsor-quest gate met, sponsor's shop open, and not
-- already completed (unless the quest is `repeatable`).
--
-- NOTHING SHIPPED SETS `repeatable`, AND NOTHING SHOULD. The design rule is that this game has no
-- grind: every quest is authored, runs once, and means something the second time only in memory.
-- The slot each line once spent on a farmable bounty is now a one-off (docs/story.md's slot 6 --
-- "the player becomes the hand that does this"), which is a beat a repeat actively destroys: run
-- once it is an accusation, run eleven times for gold it is a chore the player has tuned out.
-- The field is still honoured here so a `repeatable` def cannot silently misbehave (the specs build
-- synthetic ones to pin the double-payout and duplicate-recruit guards), not as an invitation.
--
-- Prestige, the sponsor-quest gate, and the sponsor's unlock are HARD gates: fail one and the quest is
-- not on the board at all. A
-- `requiredQuests` gate is SOFT: once the player holds at least one of the prerequisites, the quest
-- appears `locked`, carrying its key count and the hints earned so far. Seeing what you have not yet
-- earned is the point of a ladder -- the same reason Vendor.stock returns quest-locked items flagged
-- rather than hidden. The caller must refuse to start a locked quest (see ui/panels/quest_board.lua).
--
-- THE ONE-KEY CASE IS EFFECTIVELY HARD, and the sin lines lean on it. A quest naming a SINGLE
-- prerequisite has `keysHeld >= 1` and `questsMet` become true at the same instant, so it is hidden
-- outright until its predecessor is done rather than shown locked. That is what lets every sin line
-- run as a chain -- slot 5 names slot 4, and the board shows a line's next card and nothing further
-- (docs/story.md, "The ten slots"). The soft, show-it-locked behaviour is for the multi-key case that
-- wants it: the Gate Below, where being two keys short is information worth putting on the board.
function Quest.available(player)
    local prestige = player.prestige or 1

    -- Debug "show all quests": drop every gate so a locked or prerequisite-gated line can be run
    -- without progressing to it naturally, and let a finished quest be re-run to test it again. Never
    -- reachable in a release build (Debug.on ANDs in Debug.enabled), and it changes only what the
    -- board OFFERS -- Quest.complete's double-payout guard still stands, so a re-run pays nothing.
    local showAll = Debug.on("showAllQuests")

    local list = {}
    for id, def in pairs(Quest.defs) do
        local unlocked = prestige >= (def.requiredPrestige or 1)
            and meetsSponsorQuestGate(player, def) and meetsSponsorGate(player, def)
        local exhausted = Player.hasCompleted(player, id) and not def.repeatable
        local questsMet, keysHeld, keysNeeded = questGate(player, def)
        local locked = not questsMet
        if showAll then unlocked, exhausted, locked = true, false, false end

        if unlocked and not exhausted and (questsMet or keysHeld >= 1 or showAll) then
            local sponsor = def.sponsor and Vendor.get(def.sponsor)
            list[#list + 1] = {
                id = id,
                name = def.name,
                description = def.description,
                difficulty = def.difficulty,
                rewardGold = def.rewardGold,
                rewardPrestige = def.rewardPrestige or 0,
                rewardItems = def.rewardItems, -- item ids granted on completion (a general's relic)
                -- A character id who JOINS on completion. This is how a class line's main companion
                -- is earned (docs/story.md, "The other seven": each companion is earned near the head
                -- of their vendor's line, never behind another, so no ordering can strand the
                -- endgame). Surfaced on the board entry so the quest can advertise it -- a companion
                -- is the strongest reward in the game and must not arrive as a surprise.
                rewardCharacter = def.rewardCharacter,
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
                -- Optional conversation ids (data/conversations/): a scene played when the quest is
                -- started (before party select) and when its objective is cleared. See
                -- ui/panels/quest_board.lua and states/game.lua for the Conversation.play seams.
                intro = def.intro,
                outro = def.outro,
                -- A scene played over the overworld once the leg is generated (states/game.lua's
                -- `enter`). Distinct from `intro`, which plays over the hub before party select:
                -- this one has the road and the fog sitting behind it.
                opening = def.opening,
                -- The campaign's last quest: its outro rolls the credits instead of returning to the
                -- hub (states/game.lua). A flag rather than a quest id known to the engine, so an
                -- alternate or additional ending is a data edit and nothing else.
                endsCampaign = def.endsCampaign,
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

-- A single quest by id, as a fresh runtime copy (like the board entries in Quest.available) with its id
-- stamped on. Used to rehydrate the quest behind a RESUMED overworld run (models/save.lua): the run stores
-- only the quest id, and this rebuilds the object states/game.lua needs (map, name, opening, outro, ...).
-- Returns nil for an id no longer in data/, so a run whose quest was removed is dropped rather than crashing.
function Quest.get(id)
    local def = id and Quest.defs[id]
    if not def then return nil end
    local q = {}
    for k, v in pairs(def) do q[k] = v end
    q.id = id
    return q
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

    Player.addGold(player, gold)
    -- Prestige where it stood before this quest paid out. A level costs several prestige, so MOST
    -- quests move the company forward without levelling anyone -- and an overlay that can only report
    -- level-ups would answer half of all quests with silence. The pair below is what lets the
    -- advancement panel show the step itself filling (ui/panels/advancement.lua).
    local prestigeBefore = player.prestige
    -- Prestige raises every roster member's level; the returned summary (who advanced, and their stat
    -- gains from what they have been casting) rides out in the reward table for the advancement overlay.
    local advancement = Player.addPrestige(player, prestige)
    local prestigeAfter = player.prestige

    -- The sponsor's standing is its finished-quest count, so completing this quest is what advances it.
    -- Capture the count and its upgrade tier BEFORE marking done, so we can tell whether this completion
    -- crossed a tier threshold -- the moment a new wave of stock lands on the shelf, worth announcing.
    local tierBefore
    if quest.sponsor then
        tierBefore = Vendor.tier(Quest.sponsorProgress(player, quest.sponsor))
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

    -- The companion, if this quest is the one that earns them. Player.recruit instantiates a fresh
    -- copy, levels them to the company's current prestige so a late recruit is not a liability, and
    -- REFUSES a duplicate by returning nil -- so a repeatable quest (which skips the double-payout
    -- guard above) can never mint a second copy of the same character.
    --
    -- Deliberately LAST of the grants, and after Player.addPrestige above. A companion earned by a
    -- quest did not fight it, so they must not appear in that quest's advancement list -- they join
    -- already synced to the new level (Player.recruit -> Player.syncLevels) rather than showing up as
    -- someone who levelled. It also means a recruit who arrives holding their own signature relic has
    -- it in hand before any UI reads the summary.
    local recruited
    if quest.rewardCharacter then
        recruited = Player.recruit(player, quest.rewardCharacter)
    end

    -- Forging materials: `rewardMaterials = { material_steel_ingot = 3 }` accrues into the player's stock
    -- (models/material.lua), the raw metal the Blacksmith spends on upgrades. Guarded by the same
    -- double-payout check at the top, so a re-cleared tile can't mint a second haul.
    local materials = {}
    for matId, count in pairs(quest.rewardMaterials or {}) do
        Player.addMaterial(player, matId, count)
        materials[matId] = count
    end

    Player.save()

    local sponsorQuests = quest.sponsor and Quest.sponsorProgress(player, quest.sponsor)
    return {
        gold = gold,
        prestige = prestige,
        received = received, -- item instances, for the reward panel to name
        materials = materials, -- { id = count } granted, for the reward panel to name
        -- The companion instance that just joined, or nil (including when they were already owned).
        -- The reward panel should announce this LOUDEST -- it is the only reward that changes who
        -- the player is fielding.
        recruited = recruited,
        advancement = advancement, -- roster members that leveled up, for the advancement overlay
        -- Where the company's prestige stood either side of this payout. The advancement overlay fills
        -- its bar from one to the other, which is how a quest that levelled nobody still reads as
        -- progress rather than as nothing happening.
        prestigeBefore = prestigeBefore,
        prestigeAfter = prestigeAfter,
        sponsor = quest.sponsor,
        sponsorQuests = sponsorQuests, -- the sponsor's new finished-quest count (its standing), for the reward panel
        -- True when this completion crossed a tier threshold -- the moment a fresh wave of stock
        -- appears on the sponsor's shelf, and the thing worth announcing.
        unlockedStock = tierBefore ~= nil and Vendor.tier(sponsorQuests or 0) > tierBefore,
    }
end

return Quest
