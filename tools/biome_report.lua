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

-- The pick, per policy. Neither uses RNG: two runs of this tool agree.
local function pick(policy, reachable, lastSponsor, doneBySponsor)
    if #reachable == 0 then return nil end
    if policy == "committed" then
        -- Stay with the house you were working, if it has anything reachable today.
        for _, q in ipairs(reachable) do
            if q.sponsor == lastSponsor then return q end
        end
        return reachable[1]
    end
    -- breadth: the house you have done least for, ties broken by name so the walk is determined.
    local best
    for _, q in ipairs(reachable) do
        local mine = doneBySponsor[q.sponsor or "-"] or 0
        if not best or mine < (doneBySponsor[best.sponsor or "-"] or 0)
            or (mine == (doneBySponsor[best.sponsor or "-"] or 0) and q.name < best.name) then
            best = q
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
local function walk(policy, verbose, noWindows)
    local player = newPlayer()
    local doneBySponsor, lastSponsor = {}, nil

    local starved, blocked = 0, 0
    local emptyByBiome = {}
    local starvedDays, blockedDays = {}, {}
    local poolByDay = {}

    for day = 1, Calendar.DAYS do
        player.day = day
        local open = noWindows and BiomeWindow.ids() or BiomeWindow.openOn(day)
        local pool = livePool(player)
        poolByDay[day] = #pool

        -- Sort the live pool into the open grounds. A quest lands in every open ground it names, which
        -- is exactly what the board's tabs will do with it.
        local byBiome, reachable, seen = {}, {}, {}
        for _, id in ipairs(open) do byBiome[id] = {} end
        for _, q in ipairs(pool) do
            local def = Quest.defs[q.id]
            local dests = noWindows and BiomeWindow.biomesOf(def) or BiomeWindow.destinations(def, day)
            if noWindows and #dests == 0 then dests = open end
            for _, id in ipairs(dests) do
                if byBiome[id] then byBiome[id][#byBiome[id] + 1] = q end
                if not seen[q.id] then
                    seen[q.id] = true
                    reachable[#reachable + 1] = q
                end
            end
        end

        local emptyHere = {}
        for _, id in ipairs(open) do
            if #byBiome[id] == 0 then
                emptyHere[#emptyHere + 1] = id
                emptyByBiome[id] = (emptyByBiome[id] or 0) + 1
            end
        end
        if #emptyHere > 0 then
            starved = starved + 1
            starvedDays[#starvedDays + 1] = day .. " (" .. table.concat(emptyHere, ", ") .. ")"
        end
        if #reachable == 0 and #pool > 0 then
            blocked = blocked + 1
            -- Name the quests that were live and out of reach, with the grounds they are pinned to
            -- and the grounds that were open. This is the widening pass's worklist: the fix for a
            -- blocked day is always "one of these quests should also be runnable in one of those".
            local stranded = {}
            for _, q in ipairs(pool) do
                stranded[#stranded + 1] = "        " .. pad(q.id, 42)
                    .. table.concat(BiomeWindow.biomesOf(Quest.defs[q.id]), "+")
            end
            blockedDays[#blockedDays + 1] = {
                day = day, open = table.concat(open, ", "), stranded = stranded,
            }
        end

        if verbose then
            local cells = {}
            for _, id in ipairs(open) do
                local houses = {}
                local seenHouse = {}
                for _, q in ipairs(byBiome[id]) do
                    local s = q.sponsor or "-"
                    if not seenHouse[s] then
                        seenHouse[s] = true
                        houses[#houses + 1] = s:sub(1, 4)
                    end
                end
                cells[#cells + 1] = pad(id:sub(1, 4) .. " " .. #byBiome[id]
                    .. (#houses > 0 and (" [" .. table.concat(houses, ",") .. "]") or " --"), 26)
            end
            print("  " .. rpad(day, 3) .. "  " .. table.concat(cells, ""))
        end

        local chosen = pick(policy, reachable, lastSponsor, doneBySponsor)
        if chosen then
            player.completedQuests[chosen.id] = true
            doneBySponsor[chosen.sponsor or "-"] = (doneBySponsor[chosen.sponsor or "-"] or 0) + 1
            lastSponsor = chosen.sponsor
        end
        -- No pick means the day was spent foraging, which the calendar charges for anyway. The player
        -- state simply does not advance, which is precisely the cost a blocked day imposes in play.
    end

    local ran = 0
    for _, n in pairs(doneBySponsor) do ran = ran + n end
    return {
        starved = starved, blocked = blocked, ran = ran,
        emptyByBiome = emptyByBiome, starvedDays = starvedDays, blockedDays = blockedDays,
        doneBySponsor = doneBySponsor, poolByDay = poolByDay,
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
        local r = walk(policy.id, full)
        local base = walk(policy.id, false, true)
        if full then print("") end
        print("  quests run in " .. Calendar.DAYS .. " days: " .. r.ran
            .. "   (baseline with no windows: " .. base.ran .. ")")
        print("  days the schedule cost: " .. (base.ran - r.ran))

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
