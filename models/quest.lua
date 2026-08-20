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

-- ladder above applies to a numbered slot quest. Returns nil for anything with no floor -- the early
-- slots and the named capstones (which are crossings and already cost a second line). The Gate Below
-- pins its own, since the key chain that used to imply its depth is gone.
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
-- ONE SOURCE: ERRANDS RUN. A house opens its DOOR when its circle falls and its SHELF a rung at a time
-- as you do small pieces of work for it (models/errand.lua) -- two gates on two different things, and
-- keeping them apart is the whole point.
--
-- `player.standing[vendorId]` -- circles beaten -- is deliberately NOT counted here, and it used to be.
-- That term was the descent's old banking from when the mode paid into the campaign, and once circles
-- started opening doors it began double-dipping: beating a general opened the house AND handed over the
-- first rung of its stock, so the errand the house asks for bought nothing the general had not already
-- paid for. The door and the shelf read different numbers now.
--
-- Counting the quests rather than storing a number is deliberate and predates this: it survives
-- selling a relic, or losing a save's reputation field, which no longer exists.
function Quest.sponsorProgress(player, vendorId)
    if not vendorId then return 0 end
    local done = 0
    for id in pairs(player.completedQuests or {}) do
        local def = Quest.defs[id]
        if def and def.sponsor == vendorId then done = done + 1 end
    end
    return done
end

-- THE RUNG OF THE SHELF that standing has reached, which is one below it: THE FIRST ERRAND BUYS THE
-- DOOR, not stock.
--
-- A house's opener is the piece of work that opens its shop (models/errand.lua), and it lands in the
-- same ledger as every errand after it -- so it was paying twice. The shelf's bottom band is authored
-- at slot 0, which is what a shop carries before anything is earned, and the opener also moved the
-- standing to 1. Walking through a freshly opened door therefore found ELEVEN wares on the Arcanum's
-- shelf: eight that had been unlocked since the fresh save and three the opener had just released.
-- Two bands in one visit, with the earned one indistinguishable from the free one -- and the base rack
-- never announced, because it had never been locked for the reward diff to see it open.
--
-- Offsetting here rather than re-authoring 484 slots keeps the spread exactly where the grader put it
-- (docs/shelf.md): slot N is still the Nth band up, it is simply the (N+1)th errand that reaches it.
--
-- THE OFFSET IS THE SHELF'S, NOT THE STANDING'S. The forge ceiling, the board's sponsor-quest gates and
-- the shop's own "Errands run" line all still read Quest.sponsorProgress, because those count work done
-- for a house; this counts how far up its stock that work has bought.
--
-- NOT CLAMPED AT ZERO, and the negative rung is the point: a house nobody has worked for has its bottom
-- band SHUT rather than merely unreachable, so the opener has something to open. Clamping would leave
-- slot 0 unlocked at a standing of nought -- true only because the door in front of it is shut, which is
-- a second gate doing this one's job, and it would cost the reward diff (openedStock, below) the one
-- moment where the base rack can be announced as newly on sale.
function Quest.shelfRung(player, vendorId)
    return Quest.sponsorProgress(player, vendorId) - 1
end

-- The sponsor's shelf as it stands right now, for the before/after diff below. Asks Vendor.stock the
-- same question the shop asks it (ui/panels/shop.lua), with the same three gates -- shelf rung,
-- discipline unlocked, discipline level -- so what the reward panel announces as newly on sale is
-- exactly what the player will find on sale when they walk in.
--
-- Public because the descent opens shelves too: an errand is finished on a floor, far from this file's
-- payout seam (models/errand.lua), and it has to take the same BEFORE picture through the same gates.
function Quest.shelf(player, vendorId)
    if not vendorId then return nil end
    return Vendor.stock(vendorId, Quest.shelfRung(player, vendorId), player.recipes,
        Discipline.unlockedSet(player), Discipline.levelSet(player))
end
local shelfOf = Quest.shelf

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

-- The same diff, with the wares MARKED UNSEEN on the way out -- the dot the shop draws on the new rows
-- and, through Vendor.hasMarkedStock, the dot the hub draws on the house's own door.
--
-- One function does both because the mark and the report are the same fact told twice, and they were
-- drifting: Quest.complete diffed the shelf and marked what it found, while an errand -- which opens a
-- shelf by exactly the same ledger write, just out on a descent floor rather than at the campaign's
-- payout seam -- wrote nothing at all. A house whose stock an errand had opened wore no dot anywhere,
-- so the only way to learn a rung had opened was to walk in and read a shelf forty rows deep.
--
-- Take `before` with Quest.shelf, do the ledger write, then call this. Returns nil when nothing opened.
function Quest.markOpenedStock(player, vendorId, before)
    local report = openedStock(player, vendorId, before)
    for _, entry in ipairs(report and report.items or {}) do
        Player.markNew(player, Player.NEW_STOCK, entry.id)
    end
    return report
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
    return Player.standing(player) >= Building.vendorUnlockPrestige(def.sponsor)
end

-- Does the player hold every quest this one names as a prerequisite? `requiredQuests` is a list of
-- quest ids, ALL of which must be complete -- the seven generals standing between the player and the
-- Gate Below.
--
-- Returns (met, have, need), because unlike the other two gates this one is worth SHOWING rather than
-- hiding: a player two keys short of the Gate should see that they are two keys short. Quest.available
-- surfaces it as a `locked` entry.
local function questGate(player, def)
    -- THE FINALE IS GATED BY THE CALENDAR, not by keys. He arrives on the last day whichever generals
    -- are still breathing (models/calendar.lua), so the only question here is whether it is that day.
    --
    -- The count still comes back, because the board draws it -- but it now reads as a warning about the
    -- size of the last fight rather than as a tally of permission, which is why `hintQuests` is not
    -- called `requiredQuests` any more.
    if def.finale then
        local Calendar = require("models.calendar")
        local keys = def.hintQuests or {}
        return Calendar.isFinalDay(player), #keys - Calendar.generalsStanding(player), #keys
    end

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
    for _, questId in ipairs(def.hintQuests or def.requiredQuests or {}) do
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
    -- Campaign standing: quests finished, on the scale the blueprints are authored in
    -- (Player.standing). Was `player.prestige`, which nothing increments any more.
    local prestige = Player.standing(player)

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

        -- `keysHeld >= 1` is the rule for showing an ordinary locked quest: hold one key of several and
        -- the board admits the thing exists.
        --
        -- THE FINALE IS THE EXCEPTION, AND IT ASKS FOR ALL SEVEN. It was shown from the second morning
        -- for a while, on the reasoning that a deadline nobody can see is not a deadline. What that
        -- actually produced was a locked card riding along under every tab on the board for thirty-nine
        -- mornings -- a row the player cannot press, cannot travel to, and has already read. A warning
        -- repeated every day is wallpaper, and the deadline it was meant to carry is said better by the
        -- thing that says it already: the hub's own day counter, which is on screen the whole time.
        --
        -- So the card comes back to meaning something. Seven generals down and the fragments name the
        -- place: THAT is when the Gate is a thing you have found rather than a thing you were told
        -- about, and it stands on the board from then until the day he lands. A player who felled fewer
        -- meets him on day forty all the same (questsMet, above, is the calendar) -- they simply never
        -- had the pane, because they never had the fragments that fill it.
        local showable
        if def.finale then
            showable = def.showLocked and keysNeeded > 0 and keysHeld >= keysNeeded
        else
            showable = def.showLocked and keysHeld >= 1
        end
        if unlocked and not exhausted and (questsMet or showable or showAll) then
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
                -- The finale carries both: the flag that says the calendar gates it, and the seven line-enders it
                -- reads for hints and for the size of the last fight (data/quests/quest_the_gate_below.lua).
                finale = def.finale,
                hintQuests = def.hintQuests,
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

-- ---------------------------------------------------------------------------
-- The board: what is on offer, and where you would have to go for it
-- ---------------------------------------------------------------------------

-- WHAT THE BOARD OFFERS TODAY, grouped by the ground each expedition would be run on.
--
-- DELIBERATELY NOT FOLDED INTO Quest.available, which answers a different question and must keep
-- answering it. `available` is "what has this company unlocked" -- standing, the sponsor chain, the
-- house's door, keys -- and roughly forty specs ask it exactly that. The season table
-- (models/biome_window.lua) asks "and can you get there this morning", which is a property of the DAY
-- rather than of the player's progress: a quest filtered out by a shut window is not locked, it is
-- somewhere you cannot currently walk to, and it comes back untouched when the ground reopens.
--
-- tests/quest_board_spec.lua already draws this line for foraging ("what the QUEST BOARD offers, which
-- is not the same question as what Quest.available returns"), and it draws it for the same reason.
--
-- Returns:
--     { day = n, grounds = { { id, daysLeft, quests = { <available entry>, ... } }, ... } }
--
-- Grounds come back in schedule order and INCLUDE EMPTY ONES. The panel drops those after it has added
-- its own foraging rows -- a ground holding nothing but ore is still somewhere worth going, and only
-- the panel knows whether it put a row there.
--
-- A quest appears under EVERY open ground it names, because it can genuinely be run in any of them;
-- the ground the player picks is stamped onto the run (Quest.start).
--
-- THE LAST MORNING IS THE ONE EXCEPTION, and it belongs to the Gate alone. Every other ground stays in
-- the returned list -- they are open, the schedule says so -- but nothing is filed under them, so the
-- panel's own rule (a ground with nothing in it draws no tab) collapses the travel row to a single
-- plate over a single quest. There is no expedition to weigh on day forty; he is here, and a board
-- still offering the Bastion's next errand beside him would be the game hiding its own ending behind a
-- tab. Foraging is already off on this day for the same reason (ui/panels/quest_board.lua).
function Quest.board(player)
    local BiomeWindow = require("models.biome_window")
    local Calendar = require("models.calendar")
    local day = Calendar.day(player)

    local grounds, byId = {}, {}
    for _, id in ipairs(BiomeWindow.openOn(day)) do
        local ground = { id = id, daysLeft = BiomeWindow.daysLeft(id, day), quests = {} }
        grounds[#grounds + 1] = ground
        byId[id] = ground
    end

    local entries = Quest.available(player)
    if Calendar.isFinalDay(player) then
        local only = {}
        for _, entry in ipairs(entries) do
            if entry.finale then only[#only + 1] = entry end
        end
        -- Guarded on there BEING a finale to offer. Past the deadline the Gate is completed and drops
        -- off `available` entirely (New Game+ rewinds the clock, models/player.lua); emptying the board
        -- on a day that has no ending left to protect would just be a blank panel.
        if #only > 0 then entries = only end
    end

    local locked = {}
    for _, entry in ipairs(entries) do
        local def = Quest.defs[entry.id]

        -- A LOCKED ENTRY IS A WARNING, NOT A DESTINATION, so it rides along with every ground rather
        -- than claiming one -- held back to a second pass below, once every ground exists. Only the
        -- finale is ever shown locked (Quest.available's `showLocked`), and it is on the board for one
        -- reason: a deadline nobody can see is not a deadline. But it names the underworld, which is
        -- open for the last three days only, so filing it by ground put a permanent "The Underworld"
        -- tab in the travel row from the second morning of the campaign -- a place you cannot go,
        -- wearing a countdown that read blank. Wherever the company travels, the Gate is what is
        -- coming; that is what this says instead.
        if entry.locked then
            locked[#locked + 1] = entry
        else
            for _, groundId in ipairs(BiomeWindow.destinations(def, day)) do
                -- The finale is exempt from the schedule (BiomeWindow.destinations), so once it
                -- unlocks it can in principle name a ground with no tab. Give it one rather than
                -- dropping it: a last battle nobody can reach is the one failure this whole system
                -- must not be able to produce. In the shipped data this never fires -- the underworld
                -- is open on the last day, which is the only day the Gate is startable -- and it is
                -- here so that a mis-edited season table degrades into an odd tab rather than into a
                -- campaign with no ending.
                if not byId[groundId] then
                    local ground = { id = groundId, daysLeft = BiomeWindow.daysLeft(groundId, day), quests = {} }
                    grounds[#grounds + 1] = ground
                    byId[groundId] = ground
                end
                local into = byId[groundId].quests
                into[#into + 1] = entry
            end
        end
    end

    -- The warnings, after every ground is known. `startable` is what the panel counts when it decides
    -- whether a ground is worth a tab at all -- a ground holding nothing but the Gate's countdown is
    -- still a ground with nothing to do on it.
    for _, ground in ipairs(grounds) do
        ground.startable = #ground.quests
        for _, entry in ipairs(locked) do
            ground.quests[#ground.quests + 1] = entry
        end
    end

    return { day = day, grounds = grounds }
end

-- `Quest.start` LIVED HERE, and Quest.trip below is what replaced it.
--
-- Its whole job was to collapse a quest's SET of possible grounds down to the one the player travelled
-- to -- stamping `map.biome` onto a runtime copy so that models/overworld.lua, models/arena.lua, the
-- encounter pool and the prop scatter could go on reading the single field they always had. That is
-- still exactly what has to happen; it is just no longer a property of a quest. The ground is chosen
-- FIRST now, and the trip built for it names the ground once, at the top, for everything standing on
-- it (Quest.trip's `map.biome`).
--
-- Deleted rather than kept beside the new path: it had no callers left, and a function nothing calls
-- with two specs pointed at it reads as covered ground when it is a dead end.

-- ---------------------------------------------------------------------------
-- The trip: a ground, and everything that can be done on it in one day
-- ---------------------------------------------------------------------------

-- THE EXPEDITION IS A PLACE NOW, NOT A QUEST. The board used to hand states/game.lua a single quest and
-- the map was built to it: one objective, one spine, one payout, one trip home. A player picked a piece
-- of work and the ground was a consequence of it.
--
-- It is the other way round. The player picks WHERE to spend the day, and every piece of work that
-- ground can carry is standing on the board when they get there -- each on its own dead end, each its
-- own tickable objective (states/game.lua's checklist). Clearing one pays it and leaves you on the map
-- with the others still out there; the day is spent on entering, once, whatever you come home with.
--
-- What this function makes is an ORDINARY QUEST OBJECT as far as everything downstream is concerned: it
-- has an id, a name, and a `map` table, so models/overworld.lua, the encounter pool, the arena and the
-- save all read exactly what they always read. The only new field is `map.objectives`, a list where
-- there used to be one `map.objective`.
--
-- The id is synthesized (`trip:tundra`) and deliberately not a Quest.defs key: the run stores it
-- (models/save.lua), and a resume has to be able to tell "a ground I was walking" from "a quest that
-- has since been deleted from the data". The descent already resumes this way through a floor id that
-- is not in Quest.defs either.
Quest.TRIP_ID_PREFIX = "trip:"

-- The most fights one day's ground may roll, however many quests are standing on it. Three quests
-- authored at "12 to 16 encounters" apiece would ask for forty-odd stops, which is not a long day, it
-- is a different genre. The board's own sizing rule is sub-linear in content for the same reason
-- (models/overworld.lua's deriveDims) and its widest board holds about this many.
Quest.TRIP_ENCOUNTER_CAP = 16

-- Is this id a ground trip rather than a piece of authored work?
function Quest.isTripId(id)
    return type(id) == "string" and id:sub(1, #Quest.TRIP_ID_PREFIX) == Quest.TRIP_ID_PREFIX
end

-- Merge the encounter specs of every quest on the ground into one. The counts are SUMMED, because each
-- quest genuinely brings its own road, then capped at both ends -- and the cap is applied to the floor
-- as well, or a ground carrying four heavy quests would roll a board whose MINIMUM was past the ceiling.
--
-- The `always` lists concatenate uncapped: a guaranteed encounter is a set piece the quest is built
-- around (the finale's three elites), and dropping one silently would take a fight the author placed on
-- purpose out of the run. They are placed first and count against the total (Overworld:placeEncounters).
local function mergeEncounters(quests)
    local lo, hi, always = 0, 0, {}
    for _, q in ipairs(quests) do
        local spec = (q.map or {}).encounters
        if type(spec) == "table" then
            lo = lo + (spec.min or 0)
            hi = hi + (spec.max or spec.min or 0)
            for _, entry in ipairs(spec.always or {}) do always[#always + 1] = entry end
        else
            lo = lo + (spec or 0)
            hi = hi + (spec or 0)
        end
    end
    if hi < lo then hi = lo end
    lo = math.min(lo, Quest.TRIP_ENCOUNTER_CAP)
    hi = math.min(hi, Quest.TRIP_ENCOUNTER_CAP)
    -- Never fewer stops than the set pieces that must be on the board.
    lo, hi = math.max(lo, #always), math.max(hi, #always)
    return { min = lo, max = hi, always = #always > 0 and always or nil }
end

-- THE TRIP TO `groundId`, or nil when there is nothing to go there for.
--
-- `entries` are board entries (Quest.available's shape, as filed by Quest.board) and they arrive here
-- ALREADY FILTERED: a locked entry is a warning that rides along with every ground, and warnings do not
-- get an objective node. The caller passes the ground's startable work and nothing else.
function Quest.trip(groundId, entries)
    if not groundId then return nil end

    local quests = {}
    for _, entry in ipairs(entries or {}) do
        if not entry.locked and entry.map then quests[#quests + 1] = entry end
    end
    if #quests == 0 then return nil end

    -- One objective spec per quest, each stamped with the quest it belongs to. The cell the generator
    -- puts it on carries only the ID (models/overworld.lua) -- a spec can hold a composition FUNCTION
    -- (the finale sizes itself by who is still standing), and a run snapshot has to stay plain data.
    local objectives, keyCount, sponsors = {}, 0, {}
    for _, quest in ipairs(quests) do
        local map = quest.map or {}
        local spec = {}
        for k, v in pairs(map.objective or {}) do spec[k] = v end
        spec.questId = quest.id
        spec.name = spec.name or quest.name
        -- How deep this particular fight is, carried per objective rather than per run: three quests on
        -- one ground can sit at three different depths down three different lines, and the board no
        -- longer has a single answer to "how hard is today".
        spec.floorLevel = spec.floorLevel or quest.floorLevel
        -- ...and whose stock this particular fight salvages in. A run used to have one sponsor and one
        -- answer; the piece of work you actually took is the truer one now (states/game.lua).
        spec.houseMaterial = require("models.material")
            .houseFor((Vendor.get(quest.sponsor) or {}).class)
        objectives[#objectives + 1] = spec
        -- THE DEEPEST APPROACH KEEPS ITS LOCK, and it is the only one that does (models/overworld.lua).
        -- Key counts are authored per quest; summing them would have a player hunting six keys to spend
        -- one day, and a door you cannot open is the one failure a trip must not be able to produce.
        keyCount = math.max(keyCount, map.keyCount or 0)
        if quest.sponsor then sponsors[#sponsors + 1] = quest.sponsor end
    end

    -- WHOSE STOCK THE GROUND PAYS OUT IN, one entry per house with work here. This is where foraging
    -- went: a day used to be spendable on ore for one house instead of on a story, and against a trip
    -- that can clear three quests for the same day nobody would ever have chosen it again. The ore is
    -- what you carry off the ground now -- the caches are dealt round-robin across these houses
    -- (models/overworld.lua's placeCaches), so travelling somewhere three houses are working pays all
    -- three, partially, and no single trip fills every quota.
    --
    -- Two sources, in this order and deduped. The houses with WORK here take the near caches, because
    -- they are the reason the company travelled; the houses that merely FORAGE here (Request.housesIn --
    -- the same table that used to decide which forage rows the board drew) take what is left. A ground
    -- nobody has posted work on still pays somebody's stock, which is what keeps an open ground from
    -- ever being a dead end.
    local Material = require("models.material")
    local Request = require("models.request")
    local houseMaterials, seenMat = {}, {}
    local function offerStock(mat)
        if mat and not seenMat[mat] then
            seenMat[mat] = true
            houseMaterials[#houseMaterials + 1] = mat
        end
    end
    for _, vendorId in ipairs(sponsors) do
        offerStock(Material.houseFor((Vendor.get(vendorId) or {}).class))
    end
    for _, house in ipairs(Request.housesIn(groundId)) do offerStock(house.material) end

    local biome = require("models.biome").get(groundId)
    return {
        id = Quest.TRIP_ID_PREFIX .. groundId,
        trip = true,
        groundId = groundId,
        name = biome and biome.name or groundId,
        -- The work itself, in board order, for the checklist and for the payout. Held as the board
        -- entries rather than as ids so states/game.lua can complete one without a second lookup.
        quests = quests,
        -- EVERY HOUSE WITH WORK HERE, in board order. A run used to pay its caches in one house's stock
        -- because it belonged to one house; a ground belongs to whoever is working it, so the caches
        -- pay round-robin across them (models/overworld.lua's placeCaches). This is also where
        -- foraging went: the day's ore is what you carry off the ground rather than a separate errand.
        sponsors = sponsors,
        map = {
            biome = groundId,
            encounters = mergeEncounters(quests),
            objectives = objectives,
            keyCount = keyCount,
            houseMaterials = #houseMaterials > 0 and houseMaterials or nil,
        },
    }
end

-- The trip for a ground the player is standing in front of, built off the live board. The one call the
-- quest board panel makes: it knows the ground, and everything else about what is on offer there is a
-- question for this file.
function Quest.tripFor(player, groundId)
    for _, ground in ipairs(Quest.board(player).grounds) do
        if ground.id == groundId then return Quest.trip(groundId, ground.quests) end
    end
    return nil
end

-- THE SAME TRIP, REBUILT FROM WHAT IT WAS -- for a run resumed off disk (models/save.lua).
--
-- Deliberately NOT rebuilt off the live board. Half the point of a trip is that clearing one piece of
-- work takes it off the board, so asking the board again mid-expedition would hand back a shorter list
-- than the one the player is standing on, and the checklist would lose the very rows it had just
-- ticked. The ids travel with the run; this turns them back into work.
--
-- An id that has left the data since the run was saved is skipped rather than fatal: its end is still
-- on the stored board and will simply pay nothing, which is a strictly better outcome than dropping a
-- whole expedition because one quest file was renamed.
function Quest.tripFromIds(groundId, ids)
    local entries = {}
    for _, id in ipairs(ids or {}) do
        local q = Quest.get(id)
        if q then entries[#entries + 1] = q end
    end
    return Quest.trip(groundId, entries)
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
-- The seven line-enders, one per house, each of which is a general put down. Named here rather than
-- read off the finale's `requiredQuests`, because that list is gone: under the calendar the last
-- battle happens on the last day whether or not any of them are dead (models/calendar.lua), and what
-- the count decides is who is standing beside him rather than whether the door opens.
--
-- A list rather than a derivation. "The tenth slot of each house" is true today and is exactly the kind
-- of thing a renumbering would silently break, and the failure would be a finale quietly getting easier
-- rather than anything red.
Quest.GENERAL_QUESTS = {
    "quest_colosseum_slot_10",
    "quest_cathedral_slot_10",
    "quest_hunters_lodge_slot_10",
    "quest_bastion_slot_10",
    "quest_arcanum_slot_10",
    "quest_undercroft_slot_10",
    "quest_alchemist_slot_10",
}

-- `opts.keepMeal` leaves the supper on the company. A day's expedition can now clear several pieces of
-- work on one ground (Quest.trip), and the Cafe's platter is bought for the DAY -- so the caller that
-- knows when the day ends is the one that spends it (states/game.lua's bankHaul). Without this the
-- first objective of three ate the supper and the other two fights went hungry.
function Quest.complete(player, quest, carried, opts)
    if Player.hasCompleted(player, quest.id) and not quest.repeatable then
        return nil
    end

    local gold = quest.rewardGold or 0

    Player.addGold(player, gold)

    -- NO LEVELS ARE HANDED OUT HERE ANY MORE, and the absence is the change rather than an omission.
    --
    -- Completing a quest used to be the only moment anyone levelled: it granted prestige, prestige set
    -- every roster member's level, and the advancement overlay filled a bar from one prestige to the
    -- next. All of that is gone. A body earns its level in the fighting now
    -- (models/experience.lua), resolved at the end of every battle, so by the time the objective pays
    -- out the levelling has already happened and been reported where it was earned.
    --
    -- What that costs is the overlay's best trick -- the bar that let a quest which levelled nobody
    -- still read as progress. What replaces it is the calendar: the panel now says which day of how
    -- many this was, which is a truer answer to "did that matter" than a prestige step ever was,
    -- because under a deadline the day is the thing actually being spent.
    local standingBefore = Player.questsCompleted(player)

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
    local mealSpent
    if not (opts and opts.keepMeal) then
        mealSpent = player.meal
        require("models.meal").clear(player)
    end

    -- What this quest put on its sponsor's shelf. Marked UNSEEN as well as reported, so the shop
    -- itself dots the new rows (Player.markNew) -- the reward panel names three of them, and the
    -- shelf they landed on is forty rows deep. Resolved before the save below so the marks persist
    -- with everything else this completion changed.
    local unlockedStock = Quest.markOpenedStock(player, quest.sponsor, shelfBefore)

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
    local Calendar = require("models.calendar")
    return {
        gold = gold,
        received = received, -- item instances, for the reward panel to name
        materials = materials, -- { id = count } granted, for the reward panel to name
        -- The companion instance that just joined, or nil (including when they were already owned).
        -- The reward panel should announce this LOUDEST -- it is the only reward that changes who
        -- the player is fielding.
        recruited = recruited,
        -- WHERE THE COMPANY STANDS, in the two units that replaced prestige. `day` is what was spent
        -- to be here and `days` what there is, so the panel can say "the eleventh of forty" -- the
        -- reading that used to be a prestige bar. `standing` is quests finished, which is what the
        -- town reads; it moves by exactly one here, and the pair is kept rather than the delta because
        -- a repeatable quest moves it by none.
        day = Calendar.day(player),
        days = Calendar.DAYS,
        standingBefore = standingBefore,
        standing = Player.questsCompleted(player),
        -- Level-ups are NOT reported here. They were earned and shown in the fighting
        -- (models/experience.lua); see the note above where prestige used to be granted.
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
