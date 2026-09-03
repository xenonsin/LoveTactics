-- Quest logic. Blueprints live in data/quests/<id>.lua.
--
-- THEY ARE STILL CALLED QUESTS AND THEY ARE NO LONGER PICKED. This file used to open with
-- `Quest.available` -- the quests a player may currently take -- because the Quest Board was where a
-- day began: seven houses posting work, and choosing between them was the move. The board is gone.
-- What a quest blueprint is now is an OBJECTIVE with a name, a scene either side of it and a payout,
-- and models/errand.lua seats it on a descent floor for the company to walk into.
--
-- So a house does not offer its work; a company FINDS it. Two kinds are ever seated: a house's opener,
-- which is what opens its door, and any quest a discipline hangs off. Everything else a house sponsors
-- is left where it is -- unasked rather than deleted, and one line in a discipline blueprint puts it
-- back in play.
--
-- Every quest still names a `sponsor` (a vendor id). Completing it pays gold and prestige, and --
-- because a vendor's standing simply IS how many of its quests you have finished
-- (Quest.sponsorProgress) -- unlocks more of that sponsor's shelf. That loop -- find the work, run it,
-- then spend at the shelf it just opened -- is still the game. Only the finding changed.

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
--
-- IT WAS 1, AND MOVED WHEN THE CAMPAIGN DID. The retired Quest Board took 49 of the 92 quests with it,
-- so a full campaign is 42 and paid 42 prestige where it used to pay 92 -- which put the end of the game
-- at level 21 and left New Game+ short of a ceiling it is supposed to reach. Two per quest restores both
-- ends: 84 across a campaign, 168 over a second, exactly the totals models/growth.lua was tuned against.
--
-- The knob moved HERE rather than at Growth.LEVEL_CAP for the reason the cap is not a pacing dial: the
-- level ceiling is what enemy scaling, the growth tables and every item tier are cut against, and
-- dropping it to fit a shorter campaign would re-cut all of them to say something this constant says on
-- its own. A shorter campaign whose quests are worth more is also the truer description of what changed.
Quest.PRESTIGE_PER_QUEST = 2

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
-- WHOSE WORK IS THIS -- the vendor id behind a quest id, or nil for an unsponsored one (the Gate
-- Below) and for an id no longer in data/. A one-line lookup, and it is here rather than spelled out at
-- each call site because three of them now ask it about a piece of work standing on a BOARD: the map's
-- writ marker, the day's checklist and the quest board row all draw the house's mark (ui/vendor_icons.lua)
-- and all three have only the id -- a cell carries the quest ID and nothing else of the spec
-- (models/overworld.lua), which is exactly the shape this answers for.
function Quest.sponsorOf(id)
    local def = id and Quest.defs[id]
    return def and def.sponsor or nil
end

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
-- ...AND IT IS A CLASS LEVEL NOW, not a count of finished work.
--
-- A house's shelf used to climb on the errands that house had been run for, and there are none: the
-- houses are classes, and a class is something a BODY climbs (Discipline.classLevel). So the rung is
-- how far the company has got in the class this shelf sells, read as the roster's best holder -- the
-- same reading the forge ceiling takes, and for the same reason.
--
-- The offset is gone with the opener it accounted for. Under the errand line, rung 0 was bought by a
-- house's opener and standing had to be read one short so a freshly opened door did not pay twice.
-- Nothing opens a door any more, so level 0 IS rung 0: a body with no commitment to a class sees that
-- class's bottom band and nothing above it, which is what the bottom band is for.
function Quest.shelfRung(player, vendorId)
    local def = Vendor.defs[vendorId]
    local class = def and def.class
    if not class then return require("models.discipline").CLASS_LEVEL_CAP end
    return require("models.discipline").rosterLevel(player, class)
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
-- ---------------------------------------------------------------------------
-- WHAT THE QUEST BOARD TOOK WITH IT
-- ---------------------------------------------------------------------------
--
-- `Quest.available`, `Quest.board`, `Quest.tripFor` and the four gate helpers under them stood here.
-- They answered one question -- WHICH OF THESE MAY THE PLAYER PICK THIS MORNING -- and picking is the
-- thing the board did. A descent seats work on its floors (models/errand.lua), so nothing chooses from
-- a list any more and nothing asked them.
--
-- The gates they read went with them, and it is worth naming which, because two of these words survive
-- on other objects and mean something live:
--
--   requiredPrestige         a quest's own entry cost onto a LINE. Dead: the lines are gone.
--   requiredQuests ON A QUEST  the slot chain. Dead -- models/errand.lua drops it at the door.
--   requiredQuests ON A DISCIPLINE  VERY MUCH ALIVE. It is what makes a quest a gate, and the gate
--                            quests plus each house's opener ARE the postable set (Errand.forVendor).
--   requiredSponsorQuests    dead here; the same count still gates the SHELF (models/vendor.lua).
--
-- What did not go: Quest.trip and Quest.tripFromIds build the expedition itself, and the descent leans
-- on both -- a floor is a ground carrying several ends, which is exactly the shape trip already made.


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
-- (Quest.GENERAL_QUESTS listed the seven line-enders -- `quest_<house>_slot_10`, each a general put
-- down -- and Calendar.generalsStanding counted how many were still alive off it. All seven went with
-- the retired board, so the list would answer for nothing but ids that are not there. The generals are
-- met on their circles' stairs now, and models/descent.lua's SINS is the one place the seven are named.)

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

    Player.save()

    local sponsorQuests = quest.sponsor and Quest.sponsorProgress(player, quest.sponsor)
    return {
        gold = gold,
        received = received, -- item instances, for the reward panel to name
        materials = materials, -- { id = count } granted, for the reward panel to name
        -- The companion instance that just joined, or nil (including when they were already owned).
        -- The reward panel should announce this LOUDEST -- it is the only reward that changes who
        -- the player is fielding.
        recruited = recruited,
        -- WHERE THE COMPANY STANDS. It used to report `day` and `days` too -- the eleventh of forty --
        -- for a bar on the advancement panel; there is no fortieth day and no bar (models/calendar.lua).
        -- `standing` is quests finished, which is what the town reads; it moves by exactly one here, and
        -- the pair is kept rather than the delta because a repeatable quest moves it by none.
        standingBefore = standingBefore,
        standing = Player.questsCompleted(player),
        -- Level-ups are NOT reported here. They were earned and shown in the fighting
        -- (models/experience.lua); see the note above where prestige used to be granted.
        sponsor = quest.sponsor,
        sponsorQuests = sponsorQuests, -- the sponsor's new finished-quest count (its standing), for the reward panel
        mealSpent = mealSpent, -- the meal id this quest ate through, or nil if the company went hungry
        -- The wares this completion put on the sponsor's shelf, or nil when it opened none:
        -- { vendorId, vendor = shop name, items = { { id, name, type, price }, ... } }. The reward panel
        -- lists them by name -- "run the quest, then spend at the shelf it opened" is the campaign loop,
        -- and it only closes if the player is told which shelf moved and what landed on it.
        unlockedStock = unlockedStock,
    }
end

return Quest
