-- Biome-window ledger: run with
--
--     & "E:\LOVE\lovec.exe" . biome-report [full]
--
-- Asks the one question the season table (data/biome_windows.lua) can get wrong: ON EVERY DAY OF THE
-- CAMPAIGN, DOES EVERY OPEN GROUND HOLD WORK? A window system fails silently -- a starved day looks
-- exactly like a quiet one from inside the game -- so it has to be measured from outside.
--
-- Two sections, and they answer different halves.
--
--   THE CENSUS is static: how many quests name each ground against how many days that ground is open.
--   It is the instrument the re-authoring pass is aimed at. Thirty-five of ninety-two quests were
--   authored in the castle and seven in the volcanic waste, which no schedule can fix from its side --
--   a window wide enough to carry the castle's share would prop the imbalance up instead of exposing
--   it, so the table sets castle NARROWEST and this section reports the gap that leaves.
--
--   THE WALK is dynamic, and it is the real test. A house's line is a chain, so only one of its quests
--   is ever live; what a ground actually holds on day 12 is a function of how far each of the seven
--   houses has got by then, which is the player's own choices. Two policies are walked (the same pair
--   tools/progression_report.lua uses, and for the same reason): if they disagree, the defect is
--   order-dependent starvation rather than the schedule's shape.
--
-- A DAY BUYS A GROUND, and this walk did not know that. It took ONE QUEST A DAY -- the shape of the
-- campaign before docs/progression.md's "The clock" landed -- which is why "quests run in 40 days"
-- printed 40 under every policy, why the windows measured as costing exactly zero days, and why the
-- report's own headline number could not be read as pressure. A day now buys a whole ground and
-- everything posted on it (Quest.trip), so the walk picks a GROUND and then takes what is standing
-- there.
--
-- HOW MUCH OF A GROUND THE PLAYER TAKES is the other half, and it is a live choice rather than a
-- constant -- clear every spur, or take one thing and walk out with your pockets full. Both are walked
-- and reported as BOUNDS: `all` is the ceiling on what forty days reaches, and `one` is the floor,
-- which is also precisely what the old walk was measuring without ever saying so.
--
-- A STARVED DAY is a day on which an OPEN ground holds no live quest -- the board draws a tab you can
-- travel to and find nothing at. A BLOCKED DAY is worse: no ground open today holds anything at all,
-- so the campaign has nothing to offer but foraging. Blocked days are the failure this exists to
-- catch; a handful of starved ones are tolerable and arguably good, since an empty swamp is a real
-- answer to "should I go to the swamp".
--
-- Read-only. It touches no files and mutates no save; the walk drives a throwaway player table.

local Quest = require("models.quest")
local BiomeWindow = require("models.biome_window")
local Calendar = require("models.calendar")
local Vendor = require("models.vendor")

local M = {}

-- Same pair progression_report walks, and deliberately the same ids so the two reports can be read
-- side by side.
M.POLICIES = {
    { id = "committed", label = "one house at a time" },
    { id = "breadth", label = "round-robin the houses" },
}

local function newPlayer()
    return { prestige = 1, completedQuests = {}, roster = {}, day = 1 }
end

local function pad(s, n)
    s = tostring(s)
    return s .. string.rep(" ", math.max(0, n - #s))
end

local function rpad(s, n)
    s = tostring(s)
    return string.rep(" ", math.max(0, n - #s)) .. s
end

-- ---------------------------------------------------------------------------
-- The census: authored ground against scheduled days
-- ---------------------------------------------------------------------------

local function census()
    local named, primary = {}, {}
    for _, def in pairs(Quest.defs) do
        local list = BiomeWindow.biomesOf(def)
        primary[list[1] or "(none)"] = (primary[list[1] or "(none)"] or 0) + 1
        for _, id in ipairs(list) do named[id] = (named[id] or 0) + 1 end
    end

    print("")
    print("CENSUS -- what the data says against what the schedule says")
    print("")
    print("  " .. pad("ground", 12) .. rpad("primary", 8) .. rpad("named", 7)
        .. rpad("days", 6) .. rpad("windows", 9) .. "   quests per open day")
    print("  " .. string.rep("-", 74))

    local ids = BiomeWindow.ids()
    local totalPrimary = 0
    for _, id in ipairs(ids) do
        local days = 0
        for _, w in ipairs(BiomeWindow.windows(id)) do days = days + (w[2] - w[1] + 1) end
        local p = primary[id] or 0
        totalPrimary = totalPrimary + p
        -- The load column: how much authored work each open day of this ground is carrying. A ground
        -- far above the others is one the player will always find crowded and the rest thin.
        local load = days > 0 and (p / days) or 0
        print("  " .. pad(id, 12) .. rpad(p, 8) .. rpad(named[id] or 0, 7)
            .. rpad(days, 6) .. rpad(#BiomeWindow.windows(id), 9)
            .. "   " .. string.format("%.2f", load))
    end
    print("  " .. string.rep("-", 74))
    print("  " .. pad("", 12) .. rpad(totalPrimary, 8))
    print("")
    print("  primary = quests whose FIRST named ground is this one (what the file authors today)")
    print("  named   = quests that list it anywhere (what the widening pass adds)")
    print("")
end

-- ---------------------------------------------------------------------------
-- The walk
-- ---------------------------------------------------------------------------

-- Which quests are live right now, ignoring the season table -- the pool the window then filters.
-- Quest.available already applies every other gate (standing, sponsor chain, the house's door).
local function livePool(player)
    local pool = {}
    for _, q in ipairs(Quest.available(player)) do
        if not q.locked then pool[#pool + 1] = q end
    end
    return pool
end

-- How much of the ground the company takes before it walks out. See the header: these are bounds, not
-- a guess at the median player.
M.TAKES = {
    { id = "all", label = "clear every spur" },
    { id = "one", label = "one spur, then home" },
    { id = "worn", label = "push until the ground bites" },
}

-- THE GREED DIAL, MODELLED -- a PROPOSAL under measurement, not shipped behaviour. Nothing in
-- models/ reads these; they exist so the cost can be priced before it is built.
--
-- The measured problem: `all` clears 82-92% of the campaign in forty days, so the clock's own premise
-- ("more quests than there are days") is false, and a day sweeps a whole ground because sweeping is
-- free. What is missing is a price on the FOURTH spur, and the campaign already has the mechanism --
-- Quest.SLOT_FLOOR prices depth down a LINE in difficulty rather than in permission (models/quest.lua,
-- "WHY THESE NUMBERS"). This is that same rule turned sideways: depth INTO A DAY, priced the same way.
--
-- Each objective already cleared on a ground adds STEP levels to what the next one is fought at. The
-- company pushes while the next fight is within TOLERANCE of the world's own level, and walks out when
-- it is not. Both knobs are in levels, which is the unit the ladder above is already authored in.
M.DAY_FLOOR_STEP = 2
M.DAY_FLOOR_TOLERANCE = 5

-- MEASURED, AND IT DOES NOT FIX WHAT IT WAS PROPOSED FOR. Kept because the negative result is worth
-- more than the idea was, and because it will otherwise be proposed again.
--
--     committed   75 -> 72 of 92     breadth   85 -> 80 of 92
--
-- Four to six points of clearance, against the ninety-two percent that needed explaining. The reason is
-- visible in the `full` grid: most grounds hold one to three ends, so a price on the FOURTH is a price
-- almost no day ever pays -- day 24's castle, carrying six, is the outlier the eye caught and the
-- arithmetic did not. Sweeping was never the leak.
--
-- What the clock is actually governed by has only three terms, and this touches the smallest of them:
--
--     clearance = days x ends-per-day / authored-total
--               =  40  x     2.1      /      92         = 91%
--
-- So pressure has to come from the day count, from how much AUTHORED work one ground can carry, or
-- from the size of the campaign. Difficulty inside the day is texture -- worth having against the slog
-- this same report measures, worthless against the deadline.

-- What the next fight on this ground is worth, having already taken `taken` of them today. The world's
-- level is the floor under everything (Calendar.dangerLevel), an authored SLOT_FLOOR raises it, and the
-- day's own escalation sits on top.
local function effectiveLevel(entry, day, taken)
    local danger = Calendar.dangerLevel(day)
    local floor = Quest.floorLevelFor(Quest.defs[entry.id], entry.id) or 0
    return math.max(floor, danger) + M.DAY_FLOOR_STEP * taken, danger
end

-- The board the player is looking at this morning. THE REAL ONE: Quest.board is the call
-- ui/panels/quest_board.lua draws, and asking it rather than re-deriving the ground sort here is the
-- point -- the copy that used to live in this file had already drifted from it, knowing nothing about
-- `startable` and nothing about the last morning belonging to the Gate alone.
--
-- `noWindows` is the BASELINE: the same board with the season table switched off, which is what the
-- schedule gets scored against. It has to be built by hand because Quest.board always applies the
-- windows -- correctly, since the game has no mode in which they are off.
local function boardFor(player, noWindows)
    if not noWindows then return Quest.board(player) end

    local grounds, byId = {}, {}
    for _, id in ipairs(BiomeWindow.ids()) do
        local ground = { id = id, quests = {}, startable = 0 }
        grounds[#grounds + 1] = ground
        byId[id] = ground
    end
    for _, entry in ipairs(Quest.available(player)) do
        if not entry.locked then
            local dests = BiomeWindow.biomesOf(Quest.defs[entry.id])
            if #dests == 0 then dests = BiomeWindow.ids() end
            for _, id in ipairs(dests) do
                local ground = byId[id]
                if ground then
                    ground.quests[#ground.quests + 1] = entry
                    ground.startable = #ground.quests
                end
            end
        end
    end
    return { day = player.day, grounds = grounds }
end

-- The startable work standing on a ground. Quest.board files locked entries under every ground as a
-- warning and marks the cut with `startable`, so everything past it is signage rather than a
-- destination and must never be counted as somewhere to go.
local function startableOn(ground)
    local out = {}
    for i = 1, (ground.startable or #ground.quests) do out[#out + 1] = ground.quests[i] end
    return out
end

-- WHERE THE COMPANY TRAVELS TODAY, per policy. Neither uses RNG: two runs of this tool agree.
--
-- The choice is a ground now rather than a quest, which is the player's actual decision, and it means
-- a policy is expressed as "which ground carries the house I care about" instead of "which quest do I
-- want". A ground with nothing startable on it is never chosen -- travelling somewhere purely to dig
-- is a real play, but it advances no line and would make the walk's headline unreadable.
local function pickGround(policy, board, lastSponsor, doneBySponsor)
    local best, bestKey
    for _, ground in ipairs(board.grounds) do
        local work = startableOn(ground)
        if #work > 0 then
            local key
            if policy == "committed" then
                -- Stay with the house you were working. Failing that, the ground carrying whichever
                -- house you are already deepest into -- committing means depth, so the tie goes to
                -- more of the same rather than to the fuller ground.
                local holdsLast, deepest = false, -1
                for _, q in ipairs(work) do
                    if q.sponsor == lastSponsor then holdsLast = true end
                    deepest = math.max(deepest, doneBySponsor[q.sponsor or "-"] or 0)
                end
                key = { holdsLast and 0 or 1, -deepest, ground.id }
            else
                -- breadth: the ground holding the house you have done least for.
                local shallowest = math.huge
                for _, q in ipairs(work) do
                    shallowest = math.min(shallowest, doneBySponsor[q.sponsor or "-"] or 0)
                end
                key = { shallowest, 0, ground.id }
            end

            if not bestKey
                or key[1] < bestKey[1]
                or (key[1] == bestKey[1] and key[2] < bestKey[2])
                or (key[1] == bestKey[1] and key[2] == bestKey[2] and key[3] < bestKey[3])
            then
                best, bestKey = ground, key
            end
        end
    end
    return best
end

-- `noWindows` walks the same policy with the season table switched off, which is the BASELINE the
-- schedule is scored against. Without it the walk reports absolute numbers with nothing to compare
-- them to: "25 quests in 40 days" is only bad if the same policy would have run more, and the early
-- campaign is a narrow funnel by design (standing 1 offers exactly one quest, the debut), so several
-- thin days are the game's own shape rather than the schedule's fault.
-- Exposed as M.walk below so tests/biome_window_spec.lua can assert on it directly. The walk is the
-- only thing that can tell a schedule edit from a schedule REGRESSION -- the table's own shape (three
-- grounds open, no overlaps) stays perfectly legal while the campaign becomes unplayable, which is
-- exactly what the first draft of it did.
local function walk(policy, verbose, noWindows, take)
    take = take or "all"
    local player = newPlayer()
    local doneBySponsor, lastSponsor = {}, nil

    local starved, blocked = 0, 0
    local emptyByBiome = {}
    local starvedDays, blockedDays = {}, {}
    local poolByDay, tookByDay = {}, {}
    local idleDays, exhaustedOn = 0, nil
    local order = {}

    for day = 1, Calendar.DAYS do
        player.day = day
        local board = boardFor(player, noWindows)
        local pool = livePool(player)
        poolByDay[day] = #pool

        local reachable, emptyHere = 0, {}
        for _, ground in ipairs(board.grounds) do
            local n = #startableOn(ground)
            reachable = reachable + n
            if n == 0 then
                emptyHere[#emptyHere + 1] = ground.id
                emptyByBiome[ground.id] = (emptyByBiome[ground.id] or 0) + 1
            end
        end

        if #emptyHere > 0 then
            starved = starved + 1
            starvedDays[#starvedDays + 1] = day .. " (" .. table.concat(emptyHere, ", ") .. ")"
        end
        if reachable == 0 and #pool > 0 then
            blocked = blocked + 1
            -- Name the quests that were live and out of reach, with the grounds they are pinned to
            -- and the grounds that were open. This is the widening pass's worklist: the fix for a
            -- blocked day is always "one of these quests should also be runnable in one of those".
            local stranded = {}
            for _, q in ipairs(pool) do
                stranded[#stranded + 1] = "        " .. pad(q.id, 42)
                    .. table.concat(BiomeWindow.biomesOf(Quest.defs[q.id]), "+")
            end
            local openIds = {}
            for _, g in ipairs(board.grounds) do openIds[#openIds + 1] = g.id end
            blockedDays[#blockedDays + 1] = {
                day = day, open = table.concat(openIds, ", "), stranded = stranded,
            }
        end

        local chosen = pickGround(policy, board, lastSponsor, doneBySponsor)

        if verbose then
            local cells = {}
            for _, ground in ipairs(board.grounds) do
                local work = startableOn(ground)
                local houses, seenHouse = {}, {}
                for _, q in ipairs(work) do
                    local s = q.sponsor or "-"
                    if not seenHouse[s] then
                        seenHouse[s] = true
                        houses[#houses + 1] = s:sub(1, 4)
                    end
                end
                cells[#cells + 1] = pad((ground == chosen and ">" or " ")
                    .. ground.id:sub(1, 4) .. " " .. #work
                    .. (#houses > 0 and (" [" .. table.concat(houses, ",") .. "]") or " --"), 27)
            end
            print("  " .. rpad(day, 3) .. "  " .. table.concat(cells, ""))
        end

        -- THE DAY IS SPENT HERE, and it is spent on the ground rather than on a quest. Everything
        -- taken is taken against the board AS IT STOOD THIS MORNING: clearing slot 4 does not put
        -- slot 5 on the same ground the same afternoon, because the trip was built when the company
        -- set out. That is the game's own rule (Quest.trip names the ground once, at the top, for
        -- everything standing on it) and getting it wrong here would let one day walk a whole line.
        local took = 0
        if chosen then
            local work = startableOn(chosen)

            -- Cheapest fight first, which is what a company weighing "one more spur" actually does --
            -- and it matters under `worn`, where taking the general first would end the day before the
            -- errand beside it was ever considered.
            if take == "worn" then
                table.sort(work, function(a, b)
                    local la = select(1, effectiveLevel(a, day, 0))
                    local lb = select(1, effectiveLevel(b, day, 0))
                    if la ~= lb then return la < lb end
                    return a.id < b.id
                end)
            end

            for _, q in ipairs(work) do
                if take == "worn" then
                    local level, danger = effectiveLevel(q, day, took)
                    -- Walking out is free and there is no fail state, so the company stops when the
                    -- next fight stops being worth it rather than when it is forbidden. A cost, not a
                    -- cap: nothing here refuses the spur, the player declines it.
                    if level > danger + M.DAY_FLOOR_TOLERANCE then break end
                end
                player.completedQuests[q.id] = true
                doneBySponsor[q.sponsor or "-"] = (doneBySponsor[q.sponsor or "-"] or 0) + 1
                lastSponsor = q.sponsor
                took = took + 1
                -- The order, with the day and the ground each was taken on. This is what
                -- tools/progression_report.lua replays to ask what ARRIVES inside the budget: that
                -- report walks reachability rather than a playthrough, deliberately and for good
                -- reasons of its own, so the day-bounded order has to come from here.
                order[#order + 1] = { id = q.id, day = day, ground = chosen.id, sponsor = q.sponsor }
                if take == "one" then break end
            end
        end
        if took == 0 then
            -- Either no ground was worth travelling to, or the company got there and found nothing it
            -- could take -- under `worn`, a ground holding only a general is a wasted morning. Both
            -- are days the calendar charges for and no line advances, which is exactly the cost such a
            -- day imposes in play.
            idleDays = idleDays + 1
        end
        tookByDay[day] = took

        -- THE HEADLINE THE CLOCK ACTUALLY ASKS FOR: the morning the board runs dry. A campaign whose
        -- content is exhausted before the deadline has no deadline -- "more quests than there are
        -- days" is the premise the whole forty-day frame rests on, and it is an arithmetic claim that
        -- nothing was checking.
        if not exhaustedOn and #pool == 0 and day > 1 then exhaustedOn = day end
    end

    local ran = 0
    for _, n in pairs(doneBySponsor) do ran = ran + n end
    return {
        starved = starved, blocked = blocked, ran = ran,
        emptyByBiome = emptyByBiome, starvedDays = starvedDays, blockedDays = blockedDays,
        doneBySponsor = doneBySponsor, poolByDay = poolByDay, tookByDay = tookByDay,
        idleDays = idleDays, exhaustedOn = exhaustedOn, order = order,
    }
end

M.walk = walk

function M.run(args)
    local full = false
    for _, a in ipairs(args or {}) do
        if a == "full" then full = true end
    end

    print("")
    print("BIOME-WINDOW LEDGER -- " .. Calendar.DAYS .. " days, "
        .. #BiomeWindow.ids() .. " grounds, " .. (function()
            local n = 0
            for _ in pairs(Quest.defs) do n = n + 1 end
            return n
        end)() .. " quests")

    census()

    for _, policy in ipairs(M.POLICIES) do
        print("")
        print("WALK -- " .. policy.id .. " (" .. policy.label .. ")")
        if full then
            print("")
            print("  day  open grounds: <ground> <live quests> [houses]")
        end
        print("")
        local r = walk(policy.id, full, false, "all")
        local base = walk(policy.id, false, true, "all")
        if full then print("") end

        -- THE TWO BOUNDS, and the whole reason this report was rewritten. A day buys a ground, so what
        -- forty days reaches is a RANGE set by how much of each ground the company takes -- not the one
        -- number the old walk printed.
        local total = 0
        for _ in pairs(Quest.defs) do total = total + 1 end
        print("  quests run in " .. Calendar.DAYS .. " days")
        for _, t in ipairs(M.TAKES) do
            local w = walk(policy.id, false, false, t.id)
            local b = walk(policy.id, false, true, t.id)
            print("    " .. pad(t.id .. " (" .. t.label .. ")", 32)
                .. rpad(w.ran, 3) .. " of " .. total
                .. string.format("  (%3.0f%% of the campaign)", w.ran / total * 100)
                .. "   baseline " .. rpad(b.ran, 3)
                .. "   schedule cost " .. (b.ran - w.ran))
        end

        -- DOES THE DEADLINE BIND? "There are more quests than there are days, so the campaign stops
        -- being finish-everything and becomes choose-what-to-finish" (docs/progression.md, "The clock")
        -- is an ARITHMETIC CLAIM, and it is the premise the whole forty-day frame rests on. What
        -- settles it is how much of the campaign is still standing on the last morning -- not whether
        -- the board went literally empty, which is a far weaker question and the one a first draft of
        -- this line asked. A run that clears nine tenths has no deadline worth the name even though
        -- its pool never reached zero.
        local left = total - r.ran
        print("  left unrun on the last morning: " .. left .. " of " .. total
            .. string.format("  (%.0f%%)", left / total * 100))
        if r.exhaustedOn then
            print("    the board ran DRY on day " .. r.exhaustedOn .. " -- days "
                .. r.exhaustedOn .. "-" .. Calendar.DAYS .. " had nothing left to offer")
        end
        print("  days that advanced no line: " .. r.idleDays)

        -- What a day actually pays, which is the number every piece of arithmetic downstream of
        -- "forty days is about thirty quests" was missing.
        local worked = Calendar.DAYS - r.idleDays
        print(string.format("  quests per working day: %.2f  (%d quests over %d days that ran one)",
            worked > 0 and (r.ran / worked) or 0, r.ran, worked))

        -- HOW MUCH FILTERING EACH DAY CAN TAKE. The board is a narrow funnel early -- standing 1
        -- offers exactly one quest, the debut -- and windows that bite before it widens are not
        -- pressure, they are a wall. Read against the walk above: a day whose baseline pool is 1
        -- cannot afford to lose it.
        local cells = {}
        for day = 1, Calendar.DAYS, 4 do
            cells[#cells + 1] = "d" .. day .. ":" .. (base.poolByDay[day] or 0)
        end
        print("  baseline live pool: " .. table.concat(cells, "  "))
        print("  starved days (an open ground held nothing): " .. r.starved)
        print("  BLOCKED days (nothing reachable anywhere):  " .. r.blocked
            .. "   (baseline: " .. base.blocked .. ")")
        for _, b in ipairs(r.blockedDays) do
            print("")
            print("    day " .. b.day .. " -- open: " .. b.open .. "; live but out of reach:")
            for _, line in ipairs(b.stranded) do print(line) end
        end

        local rows = {}
        for id, n in pairs(r.emptyByBiome) do rows[#rows + 1] = { id = id, n = n } end
        table.sort(rows, function(a, b) return a.n > b.n end)
        if #rows > 0 then
            print("")
            print("  open-but-empty days per ground:")
            for _, row in ipairs(rows) do
                local days = 0
                for _, w in ipairs(BiomeWindow.windows(row.id)) do days = days + (w[2] - w[1] + 1) end
                print("    " .. pad(row.id, 12) .. rpad(row.n, 3) .. " of " .. days .. " open days")
            end
        end

        print("")
        print("  quests run per house:")
        for _, v in ipairs(Vendor.list()) do
            print("    " .. pad(v.id, 16) .. rpad(r.doneBySponsor[v.id] or 0, 3))
        end
    end

    print("")
    print("Pass `full` for the day-by-day grid.")
    print("")
end

return M
