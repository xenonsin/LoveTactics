-- Board ledger: run with
--
--     & "E:\LOVE\lovec.exe" . board-report [n] [tiers]
--
-- Rolls `n` overworld boards (default 200) with the campaign's own default map params and reports
-- WHAT THE GENERATOR ACTUALLY LAID DOWN. It exists because every knob that shapes a run's offer --
-- `cacheTarget`, `combatShare`, `GUARDED_BOON_SHARE`, `GUARANTEE.rest` -- is a fraction of a fraction,
-- and the composition they produce together is not readable from any one of them.
--
-- That is not a hypothetical failure. docs/overworld.md's guarded-boon knob was carried for a whole
-- pass as "roughly two and a half boons per fight", a figure derived by multiplying the constants; the
-- boards say something else, because a boon is only guardable when a fight can actually be seated on a
-- cut vertex beside it, and no constant knows how many of those a braided maze has. THE RULE IS THE
-- SAME ONE docs/roadmap.md STATES: do not hand-derive a count, roll the boards and read what they say.
--
-- WHAT IS COUNTED, and why these:
--
--     fights      combat + elite. The cost side of every offer on the board.
--     boons       cache tiles + treasure/relic_cache stops -- exactly Overworld's GUARDABLE_KINDS plus
--                 the cache tile property. The payout side. A shrine is NOT a boon (it sells, it does
--                 not give) and neither is a rest or a merchant: those are services, and the guard rule
--                 deliberately never stands a fight in front of one.
--     guarded     boons that ended up behind a fight. The ratio of this to `boons` is the only honest
--                 read on whether the pairing pass can do its job.
--     rest        the run's one refund. Reported per board AND per fight, because what matters is how
--                 much attrition a camp is being asked to hand back, not how many camps there are.
--     tier arc    mean encounter tier by fifth of the board, walked by BFS distance from the start.
--                 A generator that means to escalate should show a rising column here; a flat column
--                 means the ramp is being swamped by its own noise term.
--
-- Read-only, and it drives Overworld directly rather than a game state, so no save is touched. Seeds
-- are sequential from a fixed base, so two runs of this tool agree exactly.

local Overworld = require("models.overworld")
local Encounter = require("models.encounter")

local M = {}

-- The campaign's default board, lifted from states/game.lua's `enter`. Kept in one place here so a
-- change to the real defaults shows up as a diff in this file rather than as a silently stale report.
local DEFAULT_ENCOUNTERS = { min = 8, max = 11 }
local DEFAULT_DAY = 20 -- mid-campaign: past every encounter's minDay gate, so the pool is full
local SEED_BASE = 20260811

local FIGHT = { combat = true, elite = true }
local BOON_KINDS = { treasure = true, relic_cache = true }

-- One board's worth of counts. Walks every cell once; the tier arc needs a BFS, which Overworld
-- already exposes for its own placement passes.
local function measure(grid)
    local r = {
        fights = 0, boons = 0, guarded = 0, rest = 0, stops = 0,
        caches = 0, services = 0, tierSum = 0, tierN = 0,
        craftStock = 0, houseStock = 0,
        byKind = {},
        depthTierSum = { 0, 0, 0, 0, 0 },
        depthTierN = { 0, 0, 0, 0, 0 },
    }

    local dist = grid:bfsDistances(grid:startCell())
    local maxD = 1
    for _, d in pairs(dist) do if d > maxD then maxD = d end end

    -- WHY a boon went unguarded. `guardBoons` gives up on a boon for one of two entirely different
    -- reasons and reports neither, which is what let the knob be mis-diagnosed as a supply problem:
    --   no approach  -- no neighbour of the boon is a cut vertex, so nothing CAN gate it. Geometry.
    --   no fight     -- there was an approach but no loose fight left to move onto it. Supply.
    -- Recomputed here rather than exported from the generator: this is a diagnostic, and threading a
    -- reason code through a placement pass to serve a report would be the report leaking into the model.
    r.deadEnds, r.cacheOnDeadEnd, r.boonsWithApproach = 0, 0, 0
    local function reachableWithout(goal, blocked)
        local start = grid:startCell()
        if not start or start == goal then return true end
        local seen, q, qi = { [start.y * 100000 + start.x] = true }, { start }, 1
        while qi <= #q do
            local c = q[qi]; qi = qi + 1
            for _, nb in ipairs(grid:pathNeighbors(c.x, c.y)) do
                if nb == goal then return true end
                local k = nb.y * 100000 + nb.x
                if not seen[k] and nb ~= blocked then seen[k] = true; q[#q + 1] = nb end
            end
        end
        return false
    end

    for y = 1, grid.rows do
        for x = 1, grid.cols do
            local c = grid.cells[y][x]
            local leaf = grid:typeWalkable(c.tile) and #grid:pathNeighbors(x, y) == 1
            if leaf then r.deadEnds = r.deadEnds + 1 end
            local isBoon = c.cache or (c.encounter and BOON_KINDS[c.encounter.kind])
            if isBoon then
                for _, nb in ipairs(grid:pathNeighbors(x, y)) do
                    if not grid.spineKeys[nb.y * 100000 + nb.x] and not nb.cache
                        and not reachableWithout(c, nb) then
                        r.boonsWithApproach = r.boonsWithApproach + 1
                        break
                    end
                end
            end
            if c.cache then
                r.caches = r.caches + 1; r.boons = r.boons + 1
                if leaf then r.cacheOnDeadEnd = r.cacheOnDeadEnd + 1 end
                -- What the board actually pays in forging stock. Counted by walking the placed caches
                -- rather than derived from cacheTarget, because the payload is scaled per tile by the
                -- detour it cost AND bumped again if the tile ended up guarded -- so the constant that
                -- looks responsible for material income is never the one that sets it.
                for mat, qty in pairs(c.cache.materials or {}) do
                    if mat == "material_salt_iron" then
                        r.houseStock = (r.houseStock or 0) + qty
                    else
                        r.craftStock = (r.craftStock or 0) + qty
                    end
                end
            end
            local e = c.encounter
            if e then
                r.stops = r.stops + 1
                r.byKind[e.kind] = (r.byKind[e.kind] or 0) + 1
                if FIGHT[e.kind] then
                    r.fights = r.fights + 1
                    if e.tier then
                        r.tierSum = r.tierSum + e.tier
                        r.tierN = r.tierN + 1
                        -- Fifth of the board by distance from the start. maxD is the far corner rather
                        -- than the objective (which sits at ~80% of it by design), so the last fifth is
                        -- genuinely the deep end and not merely "past the boss".
                        local d = dist[y * 100000 + x] or 0
                        local b = math.max(1, math.min(5, math.floor(d / maxD * 5) + 1))
                        r.depthTierSum[b] = r.depthTierSum[b] + e.tier
                        r.depthTierN[b] = r.depthTierN[b] + 1
                    end
                elseif BOON_KINDS[e.kind] then
                    r.boons = r.boons + 1
                elseif e.kind == "rest" then
                    r.rest = r.rest + 1
                    r.services = r.services + 1
                elseif e.kind ~= "objective" then
                    r.services = r.services + 1
                end
                if c.guards then r.guarded = r.guarded + 1 end
            end
        end
    end
    return r
end

function M.run(args)
    args = args or {}
    local n = tonumber(args[1]) or 200
    local wantTiers, braid, cacheDiv, combatWeight = false, nil, nil, nil
    local wantContracts, wantXp = false, false
    local perBoard = {} -- one row per board, for the distribution questions a mean cannot answer
    for _, a in ipairs(args) do
        if a == "tiers" then wantTiers = true end
        if a == "contracts" then wantContracts = true end
        if a == "xp" then wantXp = true end
        -- Override knobs for a tuning sweep, so a candidate value is measured before it is committed to
        -- the model: `. board-report 200 braid=0.25 cachediv=3`.
        local b = tostring(a):match("^braid=([%d%.]+)$"); if b then braid = tonumber(b) end
        local d = tostring(a):match("^cachediv=([%d%.]+)$"); if d then cacheDiv = tonumber(d) end
        local w = tostring(a):match("^cw=([%d%.]+)$"); if w then combatWeight = tonumber(w) end
    end

    local pool = Encounter.pool({ day = DEFAULT_DAY })
    -- Sweep the ordinary-fight weights without editing four blueprints per candidate value. The pool is
    -- meant to be fight-heavy so that Overworld's combat-share CAP is what decides the mix; when it is
    -- not, the cap stops binding and the guarantee pass's non-combat stops set the ratio by accident.
    if combatWeight then
        for _, e in ipairs(pool) do
            if e.kind == "combat" then e.weight = e.weight * combatWeight end
        end
    end

    local tot = {
        fights = 0, boons = 0, guarded = 0, rest = 0, stops = 0, caches = 0, services = 0,
        tierSum = 0, tierN = 0,
        depthTierSum = { 0, 0, 0, 0, 0 }, depthTierN = { 0, 0, 0, 0, 0 },
        byKind = {},
    }

    for i = 1, n do
        local encN = DEFAULT_ENCOUNTERS
        local grid = Overworld.generate({
            biome = "forest",
            encounterCount = encN,
            encounters = pool,
            houseMaterial = "material_salt_iron",
            braid = braid,
            -- Mirrors Overworld.generate's own derivation so a sweep can try a different divisor
            -- without editing the model. nil leaves the model's own rule in charge.
            cacheCount = cacheDiv and math.max(1, math.floor(((encN.min + encN.max) / 2) / cacheDiv)) or nil,
            seed = SEED_BASE + i,
        })
        local r = measure(grid)
        for _, k in ipairs({ "fights", "boons", "guarded", "rest", "stops", "caches", "services",
                             "tierSum", "tierN", "deadEnds", "cacheOnDeadEnd", "boonsWithApproach",
                             "craftStock", "houseStock" }) do
            tot[k] = (tot[k] or 0) + r[k]
        end
        for b = 1, 5 do
            tot.depthTierSum[b] = tot.depthTierSum[b] + r.depthTierSum[b]
            tot.depthTierN[b] = tot.depthTierN[b] + r.depthTierN[b]
        end
        for k, v in pairs(r.byKind) do tot.byKind[k] = (tot.byKind[k] or 0) + v end
        perBoard[#perBoard + 1] = {
            guarded = r.guarded, caches = r.caches, fights = r.fights,
            relicCache = r.byKind.relic_cache or 0,
            treasure = r.byKind.treasure or 0,
            crossroads = r.byKind.crossroads or 0,
        }
    end

    local function per(v) return v / n end
    local function ratio(a, b) return b > 0 and (a / b) or 0 end

    print(string.format("BOARD REPORT -- %d rolled boards, forest, %d-%d stops, day %d",
        n, DEFAULT_ENCOUNTERS.min, DEFAULT_ENCOUNTERS.max, DEFAULT_DAY))
    print("")
    print(string.format("  %-22s %8s  %s", "", "per board", "note"))
    print(string.format("  %-22s %8.2f", "stops", per(tot.stops)))
    print(string.format("  %-22s %8.2f", "fights", per(tot.fights)))
    print(string.format("  %-22s %8.2f  %s", "boons", per(tot.boons),
        string.format("%.2f caches + %.2f finds", per(tot.caches), per(tot.boons - tot.caches))))
    print(string.format("  %-22s %8.2f", "services", per(tot.services)))
    print(string.format("  %-22s %8.2f  %s", "rest", per(tot.rest),
        string.format("one per %.1f fights", ratio(tot.fights, tot.rest))))
    print("")
    -- NOT a target. The ratio was the first suspect for the guarded-boon shortfall and it was the wrong
    -- one: forcing it to 1.0 by cutting caches lowered material income by a third AND lowered the
    -- absolute number of guarded boons, because it removed boons rather than adding pairings. Kept as
    -- context for the two rows under it, which are the ones that mean something.
    print(string.format("  %-22s %8.2f  %s", "boons per fight", ratio(tot.boons, tot.fights),
        "context only -- see `boons gateable` for the real ceiling"))
    print(string.format("  %-22s %8.1f%%  %s", "boons guarded", 100 * ratio(tot.guarded, tot.boons),
        string.format("%.2f of %.2f per board", per(tot.guarded), per(tot.boons))))
    print(string.format("  %-22s %8.1f%%  %s", "fights on guard", 100 * ratio(tot.guarded, tot.fights),
        "the rest stand in the open"))
    print("")
    print("  why a boon goes unguarded -- geometry or supply:")
    print(string.format("    %-20s %8.2f  %s", "dead ends", per(tot.deadEnds),
        string.format("%.2f of %.2f caches sit on one", per(tot.cacheOnDeadEnd), per(tot.caches))))
    print(string.format("    %-20s %8.1f%%  %s", "boons gateable", 100 * ratio(tot.boonsWithApproach, tot.boons),
        "have a neighbour that is a real cut vertex"))
    print(string.format("    %-20s %8.2f  %s", "loose fights", per(tot.fights - tot.guarded),
        "available to move onto an approach"))
    print("")
    print(string.format("  %-22s %8.2f  %s", "cache craft stock", per(tot.craftStock),
        "material income -- the thing a ratio change must not quietly gut"))
    print(string.format("  %-22s %8.2f", "cache house stock", per(tot.houseStock)))
    print("")
    print(string.format("  %-22s %8.2f", "mean fight tier", ratio(tot.tierSum, tot.tierN)))
    print("  tier by fifth of board (start -> far corner):")
    local bars = {}
    for b = 1, 5 do
        local m = ratio(tot.depthTierSum[b], tot.depthTierN[b])
        bars[#bars + 1] = string.format("%.2f", m)
    end
    print("    " .. table.concat(bars, "  -> "))

    -- CONTRACT SATISFIABILITY. A side contract is accepted BEFORE the board is rolled, so what matters
    -- is not the average board but the WORST one: a contract the player took and the board cannot
    -- possibly satisfy is a broken promise, and the mean says nothing about how often that happens.
    -- Each row is the share of boards carrying at least N of the thing a candidate condition counts.
    if wantContracts then
        print("")
        print("  contract satisfiability -- share of boards carrying at least N:")
        print(string.format("    %-16s %7s %7s %7s %7s", "", "N=1", "N=2", "N=3", "N=4"))
        local axes = {
            { "guarded fights", "guarded" },
            { "caches", "caches" },
            { "fights", "fights" },
            { "relic caches", "relicCache" },
            { "treasure", "treasure" },
            { "crossroads", "crossroads" },
        }
        for _, a in ipairs(axes) do
            local cells = {}
            for n = 1, 4 do
                local hit = 0
                for _, b in ipairs(perBoard) do if (b[a[2]] or 0) >= n then hit = hit + 1 end end
                cells[#cells + 1] = string.format("%6.1f%%", 100 * hit / #perBoard)
            end
            print(string.format("    %-16s %s", a[1], table.concat(cells, " ")))
        end
    end

    -- WHAT A DAY IS WORTH IN EXPERIENCE, measured by actually fighting the board rather than estimated
    -- from a guess about how often a body swings. This is the input Experience.STEP has to be anchored
    -- on, and the last time a number like it was hand-derived (the guarded-boon knob) the boards said
    -- something else entirely.
    --
    -- Resolves every combat/elite stop on a sample of boards through models/autobattle.lua -- the same
    -- loop the walk-off path uses, so the plan, the ordering and the free-action handling are the real
    -- ones -- and reads what combat actually banked (`combat.xpByChar`). A fresh company is minted per
    -- board so attrition does not compound across boards the player would have camped between.
    if wantXp then
        local Autobattle = require("models.autobattle")
        local Combat = require("models.combat")
        local EncounterBattle = require("models.encounter_battle")
        local Muster = require("models.muster")
        local Player = require("models.player")
        local Experience = require("models.experience")
        local Calendar = require("models.calendar")

        local Character = require("models.character")
        local Growth = require("models.growth")

        -- THE COMPANY HAS TO BE AT PARITY OR THE MEASUREMENT IS OF A MASSACRE. The opening roster is
        -- one body at level 1, and a lone level-1 Rowan against day-20 stock is dead in two turns --
        -- which reads as four experience a day and is a measurement of losing, not of playing.
        --
        -- There is a circularity here worth naming: to know what level a company reaches by day N you
        -- need the curve this measurement is meant to anchor. It is resolved by ASSUMING PARITY --
        -- level the company to what the calendar says the world is worth on that day, then ask what a
        -- day pays them. That is the fixed point the curve should hold: a company keeping pace earns
        -- enough to keep pacing.
        local FIELD = 4
        local function parityCompany(day)
            local player = Player.new()
            player.day = day
            for _, id in ipairs({ "character_knight", "character_mage", "character_hunter" }) do
                if #player.roster < FIELD and Character.defs[id] then
                    player.roster[#player.roster + 1] = Character.instantiate(id)
                end
            end
            local target = Calendar.dangerLevel(day)
            for _, char in ipairs(player.roster) do
                Experience.award(char, Experience.totalFor(target))
                Growth.resolve(char, target)
            end
            return player
        end

        local BOARDS = math.min(n, 12) -- fighting is dear; a dozen boards is plenty for a mean
        local totalXp, bodies, fought, refused = 0, 0, 0, 0
        for i = 1, BOARDS do
            local player = parityCompany(DEFAULT_DAY)
            local grid = Overworld.generate({
                biome = "forest", encounterCount = DEFAULT_ENCOUNTERS, encounters = pool,
                houseMaterial = "material_salt_iron", seed = SEED_BASE + i,
            })
            local boardXp = 0
            for y = 1, grid.rows do
                for x = 1, grid.cols do
                    local e = grid.cells[y][x].encounter
                    if e and FIGHT[e.kind] then
                        local ok, built = pcall(EncounterBattle.build, {
                            encounter = e, day = DEFAULT_DAY, party = player.roster, biome = "forest",
                        })
                        if ok and built and built.combat then
                            EncounterBattle.autoDeploy(built.combat, built.arena, Muster.fielded(player))
                            Combat.openBattle(built.combat)
                            Autobattle.run(built.combat, { maxTurns = 400 })
                            for _, got in pairs(built.combat.xpByChar or {}) do boardXp = boardXp + got end
                            fought = fought + 1
                        else
                            refused = refused + 1
                        end
                    end
                end
            end
            totalXp = totalXp + boardXp
            bodies = bodies + math.max(1, #player.roster)
        end

        -- Per BODY per BOARD. `bodies` accumulated the company size once per board, so dividing the
        -- whole haul by it gives what one member banked on one board -- which is one day.
        local perDay = totalXp / math.max(1, bodies)
        print("")
        print(string.format("  EXPERIENCE A DAY -- %d boards fought, %d fights resolved, %d refused",
            BOARDS, fought, refused))
        print(string.format("    %-24s %8.1f", "xp a body a day", perDay))
        print(string.format("    %-24s %8d", "over the campaign", math.floor(perDay * Calendar.DAYS)))
        print(string.format("    %-24s %8d  %s", "which reaches level",
            Experience.levelFor(perDay * Calendar.DAYS),
            "against a world ending at " .. Calendar.FINAL_DANGER))
        print(string.format("    %-24s %8d", "at Experience.STEP", Experience.STEP))
    end

    if wantTiers then
        print("")
        print("  stops by kind, per board:")
        local kinds = {}
        for k in pairs(tot.byKind) do kinds[#kinds + 1] = k end
        table.sort(kinds)
        for _, k in ipairs(kinds) do
            print(string.format("    %-16s %6.2f", k, per(tot.byKind[k])))
        end
    end
end

return M
