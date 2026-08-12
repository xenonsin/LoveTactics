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
local Discipline = require("models.discipline") -- unlockedSet/levelSet: the shelf's other two gates
local Building = require("models.building")
local Debug = require("models.debug")

local Quest = {}

Quest.defs = Registry.load("data/quests", "data.quests")

-- What finishing ANY quest pays in prestige. Flat, and deliberately not authorable: prestige is simply
-- the count of quests the company has completed (plus whatever New Game+ carried in), so the number on
-- the character sheet answers "how far through the campaign am I" and nothing else.
--
-- There used to be a `rewardPrestige` field on every quest blueprint, paying 1, 2, 3 or -- for the Gate
-- Below -- 10, back-loaded so that slots 7-10 of each line paid double. That weighting was invisible:
-- prestige is never shown as a per-quest figure, and "this one mattered more" was already being said
-- far better by the things a late quest actually hands over -- a relic, a companion, a discipline, a
-- deeper shelf. What the field bought instead was 92 chances for the pacing to drift, in 92 files, with
-- no single place to read the campaign's total off.
--
-- Deleting the field rather than setting every copy of it to 1 is the point. A constant cannot drift.
Quest.PRESTIGE_PER_QUEST = 1

-- ---------------------------------------------------------------------------
-- The depth floor: what stops a line being beelined
-- ---------------------------------------------------------------------------

-- A house's line can be run to its end without touching the other six (see the solo walk in
-- tools/progression_report.lua). What holds a player back is meant to be HOW HARD THE FIGHTS GET, not
-- permission -- and until this existed there was no such thing as being underlevelled. Ordinary enemies
-- track the party at `Growth.ENEMY_LEVEL_LAG` (0.9x), so a beeliner at level 7 met level 6 enemies and
-- depth cost exactly nothing.
--
-- `floorLevel` on a fight is the answer, and it was already wired end to end -- quest -> states/game.lua
-- -> battle.floorLevel -> Growth.combatantLevel, where it means "this fight is never easier than this,
-- whoever walks into it". It was authored on zero quests of ninety-two. This is the ladder that fills it.
--
-- WHY DERIVED RATHER THAN AUTHORED IN 70 FILES. The floor is a function of one thing -- how deep down a
-- line the fight sits -- and seventy hand-typed numbers is seventy chances to drift, with no single
-- place to read the curve off. Same argument that deleted `rewardPrestige` above. A quest may still pin
-- its own `floorLevel` and that wins outright, so a specific beat can be made heavier without touching
-- the ladder.
--
-- WHY THESE NUMBERS. They are tuned against the SOLO pace, because a solo run is the only player they
-- can bind on -- prestige is a flat count of quests finished, so a player who has run one line and its
-- on-ramp arrives at slot N holding roughly `1 + (N + entry) / 2` levels: about 3 at slot 4, about 7 by
-- slot 10. Anyone who has played more broadly is far above the floor and never feels it, which is the
-- whole point of a floor rather than a scaling rule.
--
-- The margin is what the floor sits ABOVE that solo pace, and it widens with depth: nothing for the
-- first three slots (a line has to be enterable), then one or two levels through the middle, reaching
-- about six at slot 10 -- where the fight is a general, and a company that has done nothing else in the
-- campaign should lose it. Six levels is a hard fight, not an impossible one: mitigation is subtractive
-- (models/growth.lua) so the gap costs damage taken rather than a wall, and losing costs a retry
-- rather than a run.
--
-- These are a first pass and want playtesting. They are in one table so that is a five-minute job.
Quest.SLOT_FLOOR = { [4] = 5, [5] = 6, [6] = 8, [7] = 9, [8] = 11, [9] = 12, [10] = 13 }

-- The level floor for `def`, whose blueprint key is `id`. An authored `floorLevel` wins; otherwise the
-- ladder above applies to a numbered slot quest. Returns nil for anything with no floor -- the early
-- slots, the named capstones (which are crossings and already cost a second line), and the Gate Below
-- (which requires all seven slot 10s, so nobody arrives at it green).
function Quest.floorLevelFor(def, id)
    if not def then return nil end
    if def.floorLevel then return def.floorLevel end

    local slot = tonumber(tostring(id or ""):match("_slot_(%d+)$") or "")
    return slot and Quest.SLOT_FLOOR[slot] or nil
end

-- THE PLAYER'S STANDING WITH A HOUSE. The shelf opens (Vendor.stock) and the ability bench's cap
-- climbs (Vendor.abilityLevelCap) as this number grows, and every surface that asks "how far in am I
-- with these people" asks it here -- the shop, the forge's ceiling, the board, the reward diff. One
-- function, which is why the descent could move what feeds it without touching any of them.
--
-- TWO SOURCES, ADDED, because the game is mid-migration and both are real.
--
--   quests finished   the campaign's answer: one per completed quest naming this vendor as sponsor.
--   floors cleared    the descent's: one per extraction from that house's circle (Descent.extract).
--
-- Added rather than branched on, because a house does not have two standings. While the quest board
-- still offers legs, a player who runs one and descends a circle has done two things for the same
-- house and both should count; after stage 9 the board offers nothing new and the second term is the
-- only one that moves. It also makes the migration free in both directions: an existing save has no
-- `standing` at all and reads exactly as it did, and a save that has never touched the board still
-- opens shelves.
--
-- Counting the quests rather than storing a number is deliberate and predates this: it survives
-- selling a relic, or losing a save's reputation field, which no longer exists.
function Quest.sponsorProgress(player, vendorId)
    if not vendorId then return 0 end
    local done = (player.standing or {})[vendorId] or 0
    for id in pairs(player.completedQuests or {}) do
        local def = Quest.defs[id]
        if def and def.sponsor == vendorId then done = done + 1 end
    end
    return done
end

-- The sponsor's shelf as it stands right now, for the before/after diff in Quest.complete. Asks
-- Vendor.stock the same question the shop asks it (ui/panels/shop.lua), with the same three gates --
-- quest count, discipline unlocked, discipline level -- so what the reward panel announces as newly on
-- sale is exactly what the player will find on sale when they walk in.
local function shelfOf(player, vendorId)
    if not vendorId then return nil end
    return Vendor.stock(vendorId, Quest.sponsorProgress(player, vendorId), player.recipes,
        Discipline.unlockedSet(player), Discipline.levelSet(player))
end

-- What a completion PUT ON the sponsor's shelf: every item that was locked in `before` and is for sale
-- now. Derived by diffing the shelf rather than by re-deriving the gate here, because a shelf opens per
-- QUEST (each priced item names its own `unlockQuests`), so "did this quest open anything" has no
-- shorter honest answer than asking the shelf twice.
--
-- Returns nil when nothing opened -- most quests -- so the panel simply has no section to draw.
local function openedStock(player, vendorId, before)
    if not before then return nil end
    local wasLocked = {}
    for _, entry in ipairs(before) do
        if entry.locked then wasLocked[entry.id] = true end
    end

    local opened = {}
    for _, entry in ipairs(shelfOf(player, vendorId)) do -- already in shelf order: gate, then price
        if wasLocked[entry.id] and not entry.locked then
            opened[#opened + 1] = { id = entry.id, name = entry.name, type = entry.type, price = entry.price }
        end
    end
    if #opened == 0 then return nil end

    local def = Vendor.get(vendorId)
    return { vendorId = vendorId, vendor = def and def.name or vendorId, items = opened }
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
-- Prestige, the sponsor-quest gate, the sponsor's unlock and `requiredQuests` are all HARD gates by
-- default: fail one and the quest is not on the board at all. That is what lets every sin line run as a
-- chain -- slot 5 names slot 4, and the board shows a line's next card and nothing further
-- (docs/story.md, "The ten slots").
--
-- A quest may OPT IN to being shown locked with `showLocked`, which surfaces it from the first
-- prerequisite held, carrying its key count and the hints earned so far. The caller must refuse to
-- start a locked quest (see ui/panels/quest_board.lua).
--
-- ONLY THE GATE BELOW ASKS FOR THIS, and the flag is authored rather than inferred because the
-- inference was wrong. The rule used to be `keysHeld >= 1` -- show anything holding one key of
-- several -- which reads a PROXY (how many prerequisites a quest happens to name) for the question
-- actually being asked (does this quest want the fragments pane). It swept in all 21 discipline
-- capstones, which name two gates apiece and want none of it: they have no `gateHint` between them, so
-- every one of them fell through to the pane's "Sealed. The generals know where." fallback, promising a
-- riddle for what is really a two-quest checklist. They are advertised properly on their parent
-- vendor's shelf instead, where Discipline.missingParents turns the lock into a direction. A future
-- quest naming several prerequisites now stays hidden unless it says otherwise.
function Quest.available(player)
    local prestige = player.prestige or 1

    -- Debug "show all quests": drop every gate so a locked or prerequisite-gated line can be run
    -- without progressing to it naturally, and let a finished quest be re-run to test it again. Never
    -- reachable in a release build (Debug.on ANDs in Debug.enabled), and it changes only what the
    -- board OFFERS -- Quest.complete's double-payout guard still stands, so a re-run pays nothing.
    local showAll = Debug.on("showAllQuests")

    local list = {}
    for id, def in pairs(Quest.defs) do
        -- WHAT OPENS A LEG: three gates, ANDed, each answering a different question.
        --
        --   requiredPrestige      is the company far enough along for this LINE at all
        --   meetsSponsorQuestGate how far in are you with these people (Quest.sponsorProgress)
        --   meetsSponsorGate      is the house's door even open yet (Building.vendorUnlockPrestige)
        --
        -- THE FIRST AND THIRD WERE DELETED ONCE, AND THIS IS WHY THEY ARE BACK. They came off while the
        -- descent was the campaign's progression engine: levels came from depth then, depth was earned
        -- down the stair rather than at this board, so gating a house's work on prestige asked a question
        -- the board could not help the player answer. Every word of that was true, and none of it is now
        -- -- the descent is a separate game mode (states/descent.lua), it banks nothing, and the campaign
        -- levels off Quest.PRESTIGE_PER_QUEST again exactly as it did before. The premise died; the gates
        -- come back with it.
        --
        -- What it looked like without them: every house's opening leg on the board at once, on a brand
        -- new save, with the Alchemist's `requiredPrestige = 4` line sitting beside the Colosseum's
        -- first. The data never stopped saying so -- all 92 quests still author the field, and
        -- models/balance.lua still reads it as the line's entry gate -- it was only this reader that
        -- stopped listening.
        local unlocked = prestige >= (def.requiredPrestige or 1)
            and meetsSponsorQuestGate(player, def) and meetsSponsorGate(player, def)
        local exhausted = Player.hasCompleted(player, id) and not def.repeatable
        local questsMet, keysHeld, keysNeeded = questGate(player, def)
        local locked = not questsMet
        if showAll then unlocked, exhausted, locked = true, false, false end

        if unlocked and not exhausted and (questsMet or (def.showLocked and keysHeld >= 1) or showAll) then
            local sponsor = def.sponsor and Vendor.get(def.sponsor)
            list[#list + 1] = {
                id = id,
                name = def.name,
                description = def.description,
                difficulty = def.difficulty,
                rewardGold = def.rewardGold,
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
                -- A class line's last quest: completing it settles what that line's ten offers came to
                -- and decides whether its companion held, left, or caved (models/temptation.lua). Same
                -- shape and same reasoning as endsCampaign above -- a data flag, never an id the
                -- engine learns, so the ten slots can be renamed or renumbered freely.
                endsLine = def.endsLine,
                -- How deep down its line this fight sits, expressed as the level its enemies may
                -- never drop below (Quest.floorLevelFor). Carried on the board entry rather than
                -- resolved at battle time so the quest board can WARN with it: a soft lock nobody
                -- can see before they commit is just an unfair fight.
                floorLevel = Quest.floorLevelFor(def, id),
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
    -- Resolve the depth floor onto the copy, so a resumed run fights the same fight a fresh one does.
    q.floorLevel = Quest.floorLevelFor(def, id)
    return q
end

-- Pay out a finished quest and persist. Called once, from the objective-win branch in
-- states/game.lua. Returns a summary the UI can show, or nil if the quest was already
-- completed and is not repeatable (a guard against double payout).
--
-- `carried` is the run's own haul of forging materials -- what the party picked out of the map's
-- caches (ui/overworld_map.lua's cacheHaul). It banks HERE rather than at pickup so it rides the same
-- double-payout guard as everything else, and so the advancement panel names it with the rest of the
-- spoils. Abandoning a run therefore forfeits its haul, which is what keeps a cache from being farmed
-- by restarting the quest.
function Quest.complete(player, quest, carried)
    if Player.hasCompleted(player, quest.id) and not quest.repeatable then
        return nil
    end

    local gold = quest.rewardGold or 0

    Player.addGold(player, gold)
    -- Prestige where it stood before this quest paid out. A level costs several prestige, so MOST
    -- quests move the company forward without levelling anyone -- and an overlay that can only report
    -- level-ups would answer half of all quests with silence. The pair below is what lets the
    -- advancement panel show the step itself filling (ui/panels/advancement.lua).
    local prestigeBefore = player.prestige
    -- Prestige raises every roster member's level; the returned summary (who advanced, and their stat
    -- gains from what they have been casting) rides out in the reward table for the advancement overlay.
    local advancement = Player.addPrestige(player, Quest.PRESTIGE_PER_QUEST)
    local prestigeAfter = player.prestige

    -- The sponsor's standing is its finished-quest count, so completing this quest is what advances it.
    -- Photograph the shelf BEFORE marking done, so the payout can name the wares this quest just put
    -- on sale (openedStock above) rather than only saying that some appeared.
    local shelfBefore = shelfOf(player, quest.sponsor)

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

    -- Forging materials: the quest's own `rewardMaterials = { material_steel_ingot = 3 }` plus whatever
    -- the party carried out of the map's caches, accruing into the player's stock (models/material.lua)
    -- -- the stock the Forge spends on upgrades. Guarded by the same double-payout check at the top, so
    -- a re-cleared tile can't mint a second haul.
    local materials = {}
    local function grant(matId, count)
        if not count or count <= 0 then return end
        Player.addMaterial(player, matId, count)
        materials[matId] = (materials[matId] or 0) + count
    end
    for matId, count in pairs(quest.rewardMaterials or {}) do grant(matId, count) end
    for matId, count in pairs(carried or {}) do grant(matId, count) end

    -- The supper is eaten. A meal bought at the Cafe is bought FOR one quest (models/meal.lua's
    -- one-ration rule), and this is the objective that spends it -- so the next run is a fresh
    -- decision at the counter rather than a buff that quietly renews itself. Cleared here rather than
    -- at the run's start so a quest walked away from keeps it, alongside everything else the rollback
    -- puts back. Named in the reward table below, since a thing that just ran out should say so.
    local mealSpent = player.meal
    require("models.meal").clear(player)

    -- What this quest put on its sponsor's shelf. Marked UNSEEN as well as reported, so the shop
    -- itself dots the new rows (Player.markNew) -- the reward panel names three of them, and the
    -- shelf they landed on is forty rows deep. Resolved before the save below so the marks persist
    -- with everything else this completion changed.
    local unlockedStock = openedStock(player, quest.sponsor, shelfBefore)
    for _, entry in ipairs(unlockedStock and unlockedStock.items or {}) do
        Player.markNew(player, Player.NEW_STOCK, entry.id)
    end

    -- A line's last quest settles what its ten offers came to (models/temptation.lua): held, left, or
    -- caved. `endsLine` is a data flag on the slot-10 blueprint rather than a quest id this file knows,
    -- the same shape `endsCampaign` takes for the finale -- so a line that moves, splits, or gains an
    -- eleventh slot needs no engine edit.
    --
    -- Only the FLAG is stamped here. A companion who is leaving has an outro to say goodbye in and has
    -- to still be on the roster to say it, so the actual release is a separate beat -- states/game.lua
    -- calls Temptation.settle once that scene has finished playing.
    local temptation
    if quest.endsLine and quest.sponsor then
        temptation = require("models.temptation").resolve(player, quest.sponsor)
    end

    Player.save()

    local sponsorQuests = quest.sponsor and Quest.sponsorProgress(player, quest.sponsor)
    return {
        gold = gold,
        prestige = Quest.PRESTIGE_PER_QUEST,
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
        -- "held" | "left" | "caved" on a line's last quest, nil on every other. Not a reward and not
        -- shown on the reward panel -- the outro scene is what says it, in the companion's own voice.
        -- It rides out here so states/game.lua knows a settle is owed once that scene ends.
        temptation = temptation,
        mealSpent = mealSpent, -- the meal id this quest ate through, or nil if the company went hungry
        -- The wares this completion put on the sponsor's shelf, or nil when it opened none:
        -- { vendorId, vendor = shop name, items = { { id, name, type, price }, ... } }. The reward panel
        -- lists them by name -- "run the quest, then spend at the shelf it opened" is the campaign loop,
        -- and it only closes if the player is told which shelf moved and what landed on it.
        unlockedStock = unlockedStock,
    }
end

return Quest
