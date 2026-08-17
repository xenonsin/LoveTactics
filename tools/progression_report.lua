-- Progression ledger: run with
--
--     & "E:\LOVE\lovec.exe" . progression-report [full]
--
-- Walks the campaign quest by quest and reports WHAT ARRIVES at each one. This is the measurement
-- docs/progression.md step 7 has been waiting on, and it exists because the question that step asks
-- can no longer be answered by counting quests.
--
-- When step 7 was written, a level was the only step the player got, and it arrived every two quests
-- -- so "how long should the campaign be" and "how often does something arrive" were the same
-- question, and a headcount answered both. Steps 1-6 have since landed five more arrival sources, and
-- they do not share a cadence:
--
--     level        every 2 prestige, i.e. every 2 quests, always      (Growth.PRESTIGE_PER_LEVEL)
--     shelf rows   every quest -- but only at the house you ran       (item.unlockQuests)
--     discipline   37 of them, on specifically named quests           (Discipline.requiredQuests)
--     companion    6, on named quests                                 (quest.rewardCharacter)
--     items        66 quests grant one                                (quest.rewardItems)
--
-- A campaign is the right length when a step keeps arriving every battle or two. A dead stretch is
-- therefore where several of those go quiet AT ONCE, which no headcount can see and this walk can.
--
-- GOLD IS DELIBERATELY NOT AN ARRIVAL. All 92 quests pay it, so counting it would mark every quest a
-- step and the report would find nothing, ever. That is not an oversight in the accounting, it is the
-- doc's own argument about fungibility: four hundred coin is four hundred coin whatever you did for
-- it, so it cannot be what makes a quest feel like a rung. Same reasoning excludes technique and
-- materials, which accrue per action and per detour -- real steps, but ones that land inside a battle
-- at a rate this walk cannot know and campaign length cannot change.
--
-- WHY TWO POLICIES. Quest order is the player's, and the gates (requiredQuests on 86 quests,
-- requiredSponsorQuests on 50, requiredPrestige on all 92) admit many legal orders. Two of them are
-- natural and they pull in opposite directions:
--
--     committed   finish a house's line, then move on. Its shelf moves every quest; the other six
--                 never move at all for 12-14 quests.
--     breadth     round-robin the houses. Seven shelves each move a rung, and no house gets deep.
--
-- If those two produce different curves then length is not the defect -- order-dependent starvation
-- is, and a shorter campaign would keep it. Deciding length means reading both columns, so both are
-- walked. Neither uses RNG: the pick is fully determined, so two runs of this tool agree.
--
-- Read-only. It touches no files and mutates no save; the walk drives a throwaway player table.

local Quest = require("models.quest")
local Vendor = require("models.vendor")
local Discipline = require("models.discipline")
local Growth = require("models.growth")

local M = {}

-- Longest run of consecutive nothing-arrived quests before the report calls it out by name.
local DEAD_RUN = 2

M.POLICIES = {
    { id = "committed", label = "one house at a time" },
    { id = "breadth", label = "round-robin the houses" },
}

-- The SOLO walk is a different question from the two above, and asks it per house: run only this
-- sponsor's quests, take nothing else, and report how far down the line you get.
--
-- It exists because of a design rule that the gate data does not currently honour: a player should be
-- able to take one sin's line to its end without touching the other six, held back by how hard the
-- fights get rather than by permission. `M.walk` cannot answer that -- it always has the whole board
-- to pick from -- so this is a separate, narrower walk.
--
-- Two things this walk is deliberately strict about, or it would report success it has not measured:
--
--   IT RUNS THE NUMBERED SLOTS ONLY. A house's 2-4 named capstones are CROSSINGS by construction --
--   each names another house's line in its own requiredQuests -- so a capstone can never be solo and
--   counting it would let a "solo" run drag half the campaign in behind it. The line is the ten slots;
--   the capstones are the crossings, and the design rule is about the line.
--
--   THE ON-RAMP IS CAPPED. Prestige is a flat count of quests finished, so a house opening at prestige
--   3 needs two quests from anywhere before its first card appears -- a real and deliberate cost. But
--   an uncapped allowance turns "stuck" into "kept playing elsewhere until something shook loose",
--   which is exactly the failure this is looking for, reported as a success. Six is well clear of the
--   largest legitimate entry cost (the Alchemist's three) and nowhere near enough to run a second line.
M.SOLO_LABEL = "one house only"
M.SOLO_ONRAMP_CAP = 6

-- The walk drives a stand-in rather than a real Player, and completes quests by hand rather than
-- through Quest.complete. Deliberate: Quest.complete grants gold, mints relics into a stash and runs
-- the whole advancement path, none of which this measures, and all of which would need a roster to
-- exist. What the gates actually read is these three fields, so these three are what the walk keeps.
-- `roster` stays empty, which makes every Discipline.level 0 -- correct here, since no item authors an
-- `unlockLevel` yet (the mechanism ships defaulted to 0), so nothing on any shelf gates on it.
local function newPlayer()
    return { prestige = 1, completedQuests = {}, roster = {} }
end

-- Every shelf row the player could BUY right now, across the whole town, plus the per-vendor split.
-- Counting buyable rather than listed rows is the point: Vendor.stock emits a house's whole catalogue
-- and flags what is out of reach, so listed rows never move and would report a flat line.
local function buyableRows(player)
    local unlocked = Discipline.unlockedSet(player)
    local levels = Discipline.levelSet(player)

    local total, byVendor = 0, {}
    for _, v in ipairs(Vendor.list()) do
        local done = Quest.sponsorProgress(player, v.id)
        local n = 0
        for _, entry in ipairs(Vendor.stock(v.id, done, nil, unlocked, levels)) do
            if not entry.locked then n = n + 1 end
        end
        byVendor[v.id] = n
        total = total + n
    end
    return total, byVendor
end

-- Count of unlocked disciplines, and the set, so a step can name the ones that just opened.
local function disciplineSet(player)
    local set = Discipline.unlockedSet(player)
    local n = 0
    for _ in pairs(set) do n = n + 1 end
    return set, n
end

-- How many of `sponsor`'s quests are done, for the pick order. Unsponsored quests (the Gate Below)
-- answer nil, and the caller sorts them last.
local function sponsorCounts(player)
    local counts = {}
    for _, v in ipairs(Vendor.list()) do
        counts[v.id] = Quest.sponsorProgress(player, v.id)
    end
    return counts
end

-- The next quest to run under `policy`, or nil when the board offers nothing startable.
--
-- Locked entries are skipped: Quest.available deliberately SHOWS a multi-key quest the player cannot
-- start yet (the Gate, counting keys), and starting one is not on offer. Unsponsored quests sort last
-- so the Gate lands at the end of the walk rather than the moment its seventh key drops -- which is
-- also how a player meets it, since it is the campaign's last quest.
local function chooseQuest(policy, player, avail)
    local counts = sponsorCounts(player)

    local best
    for _, entry in ipairs(avail) do
        if not entry.locked then
            local done = entry.sponsor and counts[entry.sponsor]
            -- committed prefers the house it is already deepest into, breadth the shallowest. Same
            -- number, opposite sign, so one function walks both curves.
            local rank
            if not done then
                rank = math.huge
            elseif policy == "committed" then
                rank = -done
            else
                rank = done
            end

            local key = { rank, entry.requiredPrestige or 1, entry.id }
            if not best
                or key[1] < best.key[1]
                or (key[1] == best.key[1] and key[2] < best.key[2])
                or (key[1] == best.key[1] and key[2] == best.key[2] and key[3] < best.key[3])
            then
                best = { entry = entry, key = key }
            end
        end
    end

    return best and best.entry
end

-- The arrival accounting, shared by both walks below. Returns the throwaway player, the rows table it
-- fills, and a `credit` function that completes one quest and appends its row.
--
-- Factored out when the day-bounded walk arrived: the reachability walk picks its own order as it
-- goes and the day-bounded one is handed an order by tools/biome_report.lua, but WHAT ARRIVES at a
-- quest is the same question in both, and a second copy of it would be a second thing to keep true.
local function newLedger()
    local player = newPlayer()
    local rows = {}

    -- The opening state, so quest 1 is credited with what IT opened rather than with everything a
    -- fresh save already has. A new player can buy from every house's gate-0 stock and holds no
    -- discipline, and neither of those is an arrival.
    local rowsOpen = buyableRows(player)
    local prevDisc = disciplineSet(player)
    local level = Growth.levelForPrestige(player.prestige)

    local function credit(entry, extra)
        -- The two lines of Quest.complete this measures. See newPlayer above for why not the function.
        player.completedQuests[entry.id] = true
        player.prestige = player.prestige + Quest.PRESTIGE_PER_QUEST

        local newRows, byVendor = buyableRows(player)
        local newDiscSet = disciplineSet(player)
        local newLevel = Growth.levelForPrestige(player.prestige)

        local gained = {}
        for id in pairs(newDiscSet) do
            if not prevDisc[id] then gained[#gained + 1] = id end
        end
        table.sort(gained)

        local row = {
            n = #rows + 1,
            id = entry.id,
            name = entry.name,
            sponsor = entry.sponsor or "(none)",
            prestige = player.prestige,
            level = (newLevel > level) and newLevel or nil,
            shelf = newRows - rowsOpen,
            shelfByVendor = byVendor,
            disciplines = gained,
            joins = entry.rewardCharacter,
            items = entry.rewardItems and #entry.rewardItems or 0,
            day = extra and extra.day,
            ground = extra and extra.ground,
        }
        -- The definition of a step, and the whole point of the report: a quest is SILENT when none of
        -- the five arrival sources moved. See the header for why gold is not among them.
        row.silent = not (row.level or row.shelf > 0 or #row.disciplines > 0
            or row.joins or row.items > 0)

        rows[#rows + 1] = row
        rowsOpen, prevDisc, level = newRows, newDiscSet, newLevel
        return row
    end

    return player, rows, credit
end

-- Walk the whole campaign under one policy. Returns the ledger: one row per quest completed, in the
-- order it was run, each naming what arrived. Public so tests/progression_report_spec.lua can assert
-- on the walk itself rather than on printed text.
function M.walk(policy)
    local player, rows, credit = newLedger()

    -- THE WALK IS A REACHABILITY PROOF, NOT A PLAYTHROUGH, and the distinction became load-bearing when
    -- the campaign got a deadline. What this measures is "can every authored quest be reached at all" --
    -- i.e. is any of them orphaned behind a gate its own line cannot satisfy. It has never modelled how
    -- many quests a player has TIME for, and should not start: the calendar's budget is a tuning
    -- question (Calendar.DAYS) and this is a content-integrity question.
    --
    -- That decision stands, and M.walkDays below is what it made room for rather than an argument
    -- against it. The time question is real -- it is the largest open item in docs/progression.md --
    -- but it is a different question, it needs the ground-per-day model that lives in
    -- tools/biome_report.lua, and folding it in here would have cost the orphan check that is this
    -- walk's entire job.
    --
    -- The one place the clock has to exist here is the finale, which is gated on the last day rather
    -- than on keys. So the walk runs the board dry first and only then advances to the last day, which
    -- is exactly the order a real campaign meets them in -- and keeps the Gate walked LAST rather than
    -- taken the moment the clock is mentioned.
    local Calendar = require("models.calendar")
    player.day = 1
    local dayAdvanced = false

    while true do
        local entry = chooseQuest(policy, player, Quest.available(player))
        if not entry and not dayAdvanced then
            dayAdvanced = true
            player.day = Calendar.DAYS
            entry = chooseQuest(policy, player, Quest.available(player))
        end
        if not entry then break end
        credit(entry)
    end

    return rows
end

-- WHAT FORTY DAYS ACTUALLY REACHES. The walk above answers "is every quest reachable"; this answers
-- "how much of it does a player SEE", which is the question the clock asks and which nothing was
-- measuring -- docs/progression.md's "Where forty came from" has carried a note since the day a ground
-- replaced a quest saying every number in it was downstream of an arithmetic nobody had redone.
--
-- The order comes from tools/biome_report.lua, which owns the ground-per-day model: a day buys a
-- ground and takes what is standing on it. That report answers WHERE and WHEN; this one answers WHAT
-- ARRIVES, and handing the order across keeps each question with the walk that can actually see it.
function M.walkDays(policy, take)
    local BiomeReport = require("tools.biome_report")
    local result = BiomeReport.walk(policy, false, false, take)

    local _, rows, credit = newLedger()
    for _, step in ipairs(result.order) do
        local entry = Quest.defs[step.id]
        if entry then
            credit({
                id = step.id,
                name = entry.name,
                sponsor = entry.sponsor,
                rewardCharacter = entry.rewardCharacter,
                rewardItems = entry.rewardItems,
            }, { day = step.day, ground = step.ground })
        end
    end
    return rows, result
end

-- Walk `vendorId`'s line alone: take that house's quests whenever any is startable, and take an
-- outside quest ONLY when nothing of this house is available and the board still offers something --
-- the on-ramp. Stops when the house has nothing left to give.
--
-- Returns { sponsor, done, total, onRamp, reached, blocked }: how many of the house's quests were
-- finished, how many it has, how many outside quests the run had to spend, the deepest numbered slot
-- reached, and -- when the line did not finish -- the ids left behind.
function M.walkSolo(vendorId)
    local player = newPlayer()
    local done, onRamp, entry = 0, 0, nil

    local slots = {}
    for id, def in pairs(Quest.defs) do
        if def.sponsor == vendorId and id:match("_slot_%d+$") then slots[id] = true end
    end

    local total = 0
    for _ in pairs(slots) do total = total + 1 end

    local function cheapest(list, wantMine)
        local pick
        for _, entry in ipairs(list) do
            local mine = slots[entry.id] == true
            if not entry.locked and mine == wantMine then
                local p, q = entry.requiredPrestige or 1, pick and (pick.requiredPrestige or 1)
                if not pick or p < q or (p == q and entry.id < pick.id) then pick = entry end
            end
        end
        return pick
    end

    while done < total do
        local avail = Quest.available(player)
        local pick = cheapest(avail, true)
        local isOnRamp = false

        -- Nothing of this line on offer: spend one quest from anywhere and look again, up to the cap.
        -- Past the cap the line is not being run alone, whatever eventually shakes loose.
        if not pick then
            if onRamp >= M.SOLO_ONRAMP_CAP then break end
            pick = cheapest(avail, false)
            isOnRamp = pick ~= nil
        end

        if not pick then break end

        player.completedQuests[pick.id] = true
        player.prestige = player.prestige + Quest.PRESTIGE_PER_QUEST
        if isOnRamp then onRamp = onRamp + 1 else done = done + 1 end

        -- The on-ramp spent getting the line's FIRST card onto the board. Everything past this is the
        -- line failing to carry itself, which is the distinction the verdict turns on: a house that
        -- opens at prestige 3 legitimately costs two quests, and a house that stalls at slot 6 and is
        -- rescued by outside play has not been run alone at all.
        if done == 1 and not entry then entry = onRamp end
    end

    local reached, blocked = 0, {}
    for id in pairs(slots) do
        if player.completedQuests[id] then
            local slot = tonumber(id:match("_slot_(%d+)$") or "")
            if slot and slot > reached then reached = slot end
        else
            blocked[#blocked + 1] = id
        end
    end
    table.sort(blocked)

    -- Solo means: every numbered slot finished, and no outside quest spent beyond the entry cost.
    return {
        sponsor = vendorId, done = done, total = total,
        onRamp = onRamp, entry = entry or onRamp, reached = reached, blocked = blocked,
        solo = (#blocked == 0) and (onRamp == (entry or onRamp)),
    }
end

-- Runs of consecutive silent quests at least DEAD_RUN long, as { from, to, len }.
local function deadStretches(rows)
    local out, start = {}, nil
    for i = 1, #rows + 1 do
        local silent = rows[i] and rows[i].silent
        if silent and not start then
            start = i
        elseif not silent and start then
            local len = i - start
            if len >= DEAD_RUN then out[#out + 1] = { from = start, to = i - 1, len = len } end
            start = nil
        end
    end
    return out
end

-- Arrivals bucketed into tenths of the campaign, so back-loading and front-loading are visible
-- without reading 92 rows. A tenth is a slice of the ORDER, not of the calendar.
local function byTenth(rows)
    local buckets = {}
    for i = 1, 10 do
        buckets[i] = { quests = 0, levels = 0, shelf = 0, disc = 0, joins = 0, items = 0, silent = 0 }
    end

    for _, row in ipairs(rows) do
        local idx = math.min(10, math.floor((row.n - 1) / (#rows / 10)) + 1)
        local b = buckets[idx]
        b.quests = b.quests + 1
        if row.level then b.levels = b.levels + 1 end
        b.shelf = b.shelf + math.max(0, row.shelf)
        b.disc = b.disc + #row.disciplines
        if row.joins then b.joins = b.joins + 1 end
        if row.items > 0 then b.items = b.items + 1 end
        if row.silent then b.silent = b.silent + 1 end
    end
    return buckets
end

local function printLedger(rows)
    print("")
    print(string.format("  %3s  %-38s %-14s %5s %6s %5s %5s %5s  %s",
        "#", "quest", "house", "lvl", "shelf+", "disc", "join", "item", ""))
    print("  " .. string.rep("-", 96))
    for _, row in ipairs(rows) do
        print(string.format("  %3d  %-38s %-14s %5s %6s %5s %5s %5s  %s",
            row.n,
            (row.name or row.id):sub(1, 38),
            row.sponsor:gsub("^hunters_lodge$", "hunters"),
            row.level and tostring(row.level) or "-",
            row.shelf > 0 and ("+" .. row.shelf) or "-",
            #row.disciplines > 0 and ("+" .. #row.disciplines) or "-",
            row.joins and "yes" or "-",
            row.items > 0 and tostring(row.items) or "-",
            row.silent and "SILENT" or ""))
    end
end

local function printPolicy(policy, label, full)
    local rows = M.walk(policy)

    local levels, shelf, disc, joins, items, silent = 0, 0, 0, 0, 0, 0
    for _, row in ipairs(rows) do
        if row.level then levels = levels + 1 end
        shelf = shelf + math.max(0, row.shelf)
        disc = disc + #row.disciplines
        if row.joins then joins = joins + 1 end
        if row.items > 0 then items = items + 1 end
        if row.silent then silent = silent + 1 end
    end

    print("")
    print(string.format("policy: %s (%s)", policy, label))
    print(string.format("  quests walked ................. %d", #rows))
    print(string.format("  levels crossed ................ %d (ends at %d)",
        levels, rows[#rows] and Growth.levelForPrestige(rows[#rows].prestige) or 1))
    print(string.format("  shelf rows opened ............. %d", shelf))
    print(string.format("  disciplines unlocked .......... %d", disc))
    print(string.format("  companions joined ............. %d", joins))
    print(string.format("  quests granting an item ....... %d", items))
    print(string.format("  quests handing over NOTHING ... %d  (%.0f%%)",
        silent, #rows > 0 and (silent / #rows * 100) or 0))

    local stretches = deadStretches(rows)
    if #stretches == 0 then
        print("  no dead stretch of 2 or more")
    else
        local longest = 0
        for _, s in ipairs(stretches) do longest = math.max(longest, s.len) end
        print(string.format("  dead stretches (>= %d) ......... %d, longest %d",
            DEAD_RUN, #stretches, longest))
        for _, s in ipairs(stretches) do
            print(string.format("      quests %d-%d (%d silent): %s -> %s",
                s.from, s.to, s.len, rows[s.from].name or rows[s.from].id,
                rows[s.to].name or rows[s.to].id))
        end
    end

    print("")
    print("  arrivals by tenth of the campaign")
    print(string.format("      %-6s %6s %6s %7s %5s %5s %5s %7s",
        "tenth", "quests", "levels", "shelf+", "disc", "join", "item", "silent"))
    for i, b in ipairs(byTenth(rows)) do
        print(string.format("      %-6d %6d %6d %7d %5d %5d %5d %7d",
            i, b.quests, b.levels, b.shelf, b.disc, b.joins, b.items, b.silent))
    end

    if full then printLedger(rows) end
    return rows
end

-- THE DAY-BOUNDED TABLE: what forty days reaches, against what the campaign holds.
--
-- Read this against the reachability walk above, which always reports the whole 92. The gap between
-- the two IS the deadline -- everything the player never saw -- and it is the number "a second run has
-- a reason to exist" was always claiming without measuring.
local function printDays()
    local Calendar = require("models.calendar")
    local BiomeReport = require("tools.biome_report")

    local total = 0
    for _ in pairs(Quest.defs) do total = total + 1 end

    print("")
    print(string.format("what %d days reach -- a day buys a GROUND and takes what is standing on it",
        Calendar.DAYS))
    print("      (the walk above is a reachability proof and always reports all " .. total
        .. "; this is a budget)")
    print(string.format("      %-12s %-10s %6s %6s %7s %5s %5s %7s",
        "policy", "take", "quests", "of", "shelf+", "disc", "join", "unseen"))
    print("      " .. string.rep("-", 70))

    for _, p in ipairs(M.POLICIES) do
        for _, t in ipairs(BiomeReport.TAKES) do
            local rows = M.walkDays(p.id, t.id)
            local shelf, disc, joins = 0, 0, 0
            for _, row in ipairs(rows) do
                shelf = shelf + math.max(0, row.shelf)
                disc = disc + #row.disciplines
                if row.joins then joins = joins + 1 end
            end
            print(string.format("      %-12s %-10s %6d %6d %7d %5d %5d %6.0f%%",
                p.id, t.id, #rows, total, shelf, disc, joins,
                (total - #rows) / total * 100))
        end
    end

    print("")
    print("      unseen = the share of the authored campaign a run of this shape never reaches.")
    print("      A deadline that leaves nothing unseen is not a deadline; see docs/progression.md,")
    print("      \"Where forty came from\", whose arithmetic this exists to settle.")
end

-- The solo table: one row per house, and the verdict the design rule asks for.
local function printSolo()
    print("")
    print("solo runs -- can one sin's ten numbered slots be taken alone?")
    print(string.format("      (capstones excluded: they are crossings by construction. on-ramp capped at %d)",
        M.SOLO_ONRAMP_CAP))
    print(string.format("      %-16s %7s %5s %7s %8s   %s",
        "house", "slots", "of", "entry", "on-ramp", "verdict"))
    print("      " .. string.rep("-", 70))

    local finished = 0
    local results = {}
    for _, v in ipairs(Vendor.list()) do
        local r = M.walkSolo(v.id)
        if r.total > 0 then
            results[#results + 1] = r
            if r.solo then finished = finished + 1 end

            local verdict
            if r.solo then
                verdict = "solo"
            elseif #r.blocked > 0 then
                verdict = string.format("STOPS at slot %d, %d left", r.reached, #r.blocked)
            else
                verdict = string.format("NOT SOLO -- %d outside quests past entry", r.onRamp - r.entry)
            end

            print(string.format("      %-16s %7d %5d %7d %8d   %s",
                r.sponsor, r.done, r.total, r.entry, r.onRamp, verdict))
        end
    end

    print("")
    if finished == #results then
        print(string.format("  all %d lines run alone.", #results))
    else
        print(string.format("  %d of %d lines run alone. What stops the rest:", finished, #results))
        for _, r in ipairs(results) do
            if not r.solo then
                print("      " .. r.sponsor .. ": " ..
                    (#r.blocked > 0 and table.concat(r.blocked, ", ")
                     or string.format("finished, but on %d outside quests past its entry cost of %d",
                        r.onRamp - r.entry, r.entry)))
            end
        end
    end
end

function M.run(args)
    local full = false
    for _, a in ipairs(args or {}) do
        if a == "full" then full = true end
    end

    print("")
    print("Progression ledger -- what arrives, quest by quest")
    print(string.format("  %d quests, %d prestige each, %d prestige per level, cap %d",
        (function()
            local n = 0
            for _ in pairs(Quest.defs) do n = n + 1 end
            return n
        end)(), Quest.PRESTIGE_PER_QUEST, Growth.PRESTIGE_PER_LEVEL, Growth.LEVEL_CAP))

    local walked = {}
    for _, p in ipairs(M.POLICIES) do
        walked[p.id] = printPolicy(p.id, p.label, full)
    end

    printDays()
    printSolo()

    -- A quest the walk never reached is unreachable in that order -- a real authoring bug (a gate
    -- naming a quest its own line puts later), not a rounding difference. Worth saying loudly.
    local total = 0
    for _ in pairs(Quest.defs) do total = total + 1 end
    print("")
    for _, p in ipairs(M.POLICIES) do
        local rows = walked[p.id]
        if #rows < total then
            print(string.format("WARNING: %s reached only %d of %d quests -- %d unreachable in that order",
                p.id, #rows, total, total - #rows))
            local seen = {}
            for _, row in ipairs(rows) do seen[row.id] = true end
            for id in pairs(Quest.defs) do
                if not seen[id] then print("    unreached: " .. id) end
            end
        end
    end

    if not full then
        print("Pass `full` for the whole per-quest ledger.")
        print("")
    end
end

return M
