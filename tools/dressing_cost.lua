-- What a fight's DRESSING is worth: run with
--
--     & "E:\LOVE\lovec.exe" . dressing-cost [seeds=24] [floors=1-6] [per=2] [only=affix|condition|objective]
--
-- THE MEASUREMENT BEHIND Muster.DRESSING (models/muster.lua). The map's danger rating, the Run Away odds and
-- the walk-off gate all read a fight's worth off its roster (Muster.encounter), and a dressing -- an affixed
-- body, a condition, a rolled objective (models/dressing.lua) -- changes the fight without changing the
-- roster. This prices each one in the roster's own unit, so the table can be re-derived after any affix,
-- condition or objective is retuned.
--
-- THE METHOD, in three steps:
--
--   1. A SAMPLE of ordinary fights: the `per` heaviest dressable combats (Dressing.eligible, no party) each
--      floor in `floors` can deal, fought by the company a new save actually carries
--      (tools/early_floors.lua's company -- the avatar, Rowan, Xin, Gyeom) at Descent.expectedLevel of the
--      floor, FORCE_HIT off, each body at full health. Every fight runs `seeds` times and every VARIANT of
--      it runs off the SAME seeds, so each dressed trial is paired with an undressed one on the same board.
--
--   2. A RULER: the same undressed fights again with every enemy body's base stats scaled up (health,
--      both arms, both guards, speed) by 20%, 40% and 70%. Muster.rate is linear in those stats, so this is
--      "the same fight, worth X% more" -- and X is READ, not assumed (the enemy side is re-rated after the
--      scale, so gear and heads that do not scale are accounted for). That gives a curve from a worth
--      increase to the change in the fight's COST, joined up from the origin (see invert).
--
--   3. Each dressing played ALONE (an affix on the fight's strongest eligible body, as Affix.assign picks;
--      a condition; a rolled objective kind wherever the roster carries it), its paired change in cost read,
--      and inverted through the ruler: the multiplier is the worth increase that would cost an undressed
--      fight the same.
--
-- COST is the share of the company's health the fight took, net of healing, with a loss counted as all of
-- it -- so it reads both the win rate and the damage a won fight cost, which matters because the early
-- floors are won nearly every time and a win rate alone could not see an affix at all.
--
-- NOISE. The engine is not bit-repeatable across processes (LuaJIT table order), so a number from one run
-- is a sample. Every delta is printed with its paired standard error, and the multiplier with the error
-- carried through the ruler's local slope; a dressing whose effect is inside two standard errors is priced
-- at 1.00 rather than at its noise.
local Combat = require("models.combat")
local Descent = require("models.descent")
local Dressing = require("models.dressing")
local Affix = require("models.affix")
local Condition = require("models.condition")
local Encounter = require("models.encounter")
local EncounterBattle = require("models.encounter_battle")
local Muster = require("models.muster")
local Waves = require("models.waves")
local EF = require("tools.early_floors")

local M = {}

M.SEED_BASE = 20261025
M.SCALES = { 0.2, 0.4, 0.7 }
M.SCALED_NUMBERS = { "damage", "magicDamage", "defense", "magicDefense", "speed" }

local function isCompany(u)
    return u.side == "party" and Combat.isPlayerControlled(u)
end

local function hpOf(u)
    local h = u.char and u.char.stats and u.char.stats.health
    if type(h) == "table" then return h.current or 0, h.max or 0 end
    return 0, 0
end

-- Every enemy body's base stats up by `k`; returns the enemy side's worth after / before.
local function scaleEnemies(combat, k)
    local before, after = 0, 0
    for _, u in ipairs(combat.units) do
        if u.side == "enemy" and u.char then
            before = before + Muster.rate(u.char)
            local s = u.char.stats
            if type(s.health) == "table" then
                s.health.max = math.floor((s.health.max or 0) * (1 + k) + 0.5)
                s.health.current = s.health.max
            end
            for _, key in ipairs(M.SCALED_NUMBERS) do
                if type(s[key]) == "number" then s[key] = math.floor(s[key] * (1 + k) + 0.5) end
            end
            after = after + Muster.rate(u.char)
        end
    end
    return before > 0 and after / before or 1
end

-- One fight, one seed, one variant: { kind = "base"|"scale"|"affix"|"condition"|"objective", id?, k? }.
local function trial(f, seed, v)
    local player = EF.company(f.floor)
    math.randomseed(seed)
    if love and love.math and love.math.setRandomSeed then love.math.setRandomSeed(seed) end
    local dq = f.dq
    local rung = Descent.floorWithinCircle(f.floor)
    local dressing
    if v.kind == "affix" then dressing = { affixes = { v.id } }
    elseif v.kind == "condition" then dressing = { condition = v.id }
    elseif v.kind == "objective" then dressing = { objective = v.id } end
    local built = EncounterBattle.build({
        encounter = { id = f.id, kind = "combat", dressing = dressing },
        quest = dq, biome = dq.map.biome, depth = f.floor, rung = rung,
        enemyLevel = dq.dangerLevel, floorLevel = dq.floorLevel,
        party = player.roster, seed = seed,
    })
    local combat = built.combat
    EncounterBattle.autoDeploy(combat, built.arena, Muster.fielded(player))
    local ratio = 1
    if v.kind == "scale" then ratio = scaleEnemies(combat, v.k) end
    Combat.openBattle(combat)

    local applied = true
    if v.kind == "affix" then
        applied = false
        for _, u in ipairs(combat.units) do if u.side == "enemy" and u.affix then applied = true end end
    elseif v.kind == "objective" then
        applied = combat.objective ~= nil and combat.objective.rolled == true
    elseif v.kind == "condition" then
        applied = combat.condition ~= nil
    end
    if M.DEBUG and v.kind == "affix" then
        for _, u in ipairs(combat.units) do
            if u.side == "enemy" then
                local st = {}
                for _, x in ipairs(u.statuses or {}) do st[#st + 1] = tostring(x.id) end
                print(string.format("    DEBUG %s affix=%s statuses=[%s] traits=%d", tostring(u.char.id),
                    tostring(u.affix), table.concat(st, " "), #(u.traits or {})))
            end
        end
    end
    local obj = combat.objective
    if obj and obj.type and obj.type ~= "killAll" then
        for _, u in ipairs(combat.units) do if isCompany(u) then u.postureOverride = "objective" end end
    end

    local start = 0
    for _, u in ipairs(combat.units) do if isCompany(u) then start = start + (hpOf(u)) end end
    local ctx = { depth = f.floor, biome = dq.map.biome, rung = rung, quest = dq }
    local grow = { level = dq.dangerLevel, floor = dq.floorLevel }
    local result, turns = require("models.autobattle").run(combat, {
        maxTurns = 400,
        between = function(c)
            Waves.tick(c, ctx, grow)
            Combat.settleObjective(c)
        end,
    })
    local left = 0
    for _, u in ipairs(combat.units) do
        if isCompany(u) and u.alive then left = left + math.max(0, (hpOf(u))) end
    end
    local cost = start > 0 and math.max(0, math.min(1, (start - left) / start)) or 0
    if result == "loss" then cost = 1 end
    return { cost = cost, win = result == "win" and 1 or 0, turns = turns or 0, applied = applied,
        ratio = ratio, undecided = result == nil }
end

local function sample(fights, seeds)
    local out = {}
    for fi, f in ipairs(fights) do
        for s = 1, seeds do
            out[#out + 1] = { f = f, seed = M.SEED_BASE + s * 7919 + f.floor * 131 + fi * 17, key = fi .. ":" .. s }
        end
    end
    return out
end

-- Paired mean and standard error of (variant - base) over the trials the variant applied to.
local function paired(rows, base, field)
    local diffs = {}
    for key, r in pairs(rows) do
        local b = base[key]
        if b and r.applied then diffs[#diffs + 1] = r[field] - b[field] end
    end
    local n = #diffs
    if n == 0 then return 0, 0, 0 end
    local sum = 0
    for _, d in ipairs(diffs) do sum = sum + d end
    local mean = sum / n
    local ss = 0
    for _, d in ipairs(diffs) do ss = ss + (d - mean) ^ 2 end
    local se = n > 1 and math.sqrt(ss / (n - 1) / n) or 0
    return mean, se, n
end

-- Invert the ruler: the worth increase whose cost change is `dy`, read off the ruler's points joined up
-- from the origin (an undressed fight worth nothing more costs nothing more). Returns that increase and
-- the local slope, which carries a delta's standard error through to the multiplier's.
--
-- JOINED UP, NOT A LINE, because the response is convex -- measured, +20% worth cost the company 0.07 of
-- its health and +40% cost 0.18 -- and most dressings sit in the first stretch, where a single slope fitted
-- through all three points would read them as cheaper than they are. A dip between points is the dice and
-- is held flat (the curve is made monotone); beyond either end the nearest stretch's slope carries on.
local function invert(curve, dy)
    local pts = { { 0, 0 } }
    for _, p in ipairs(curve) do
        pts[#pts + 1] = { p[1], math.max(p[2], pts[#pts][2] + 1e-6) }
    end
    for i = 2, #pts do
        local a, b = pts[i - 1], pts[i]
        if dy <= b[2] or i == #pts then
            local slope = (b[2] - a[2]) / (b[1] - a[1])
            return a[1] + (dy - a[2]) / slope, slope
        end
    end
end

function M.run(args)
    args = args or {}
    local seeds, lo, hi, per, only = 24, 1, 6, 2, nil
    for _, a in ipairs(args) do
        a = tostring(a)
        local n = a:match("^seeds=(%d+)$"); if n then seeds = tonumber(n) end
        local x, y = a:match("^floors=(%d+)-(%d+)$"); if x then lo, hi = tonumber(x), tonumber(y) end
        local p = a:match("^per=(%d+)$"); if p then per = tonumber(p) end
        local o = a:match("^only=(.+)$"); if o then only = o end
        if a == "debug" then M.DEBUG = true end
    end
    Combat.FORCE_HIT = false

    local fights = {}
    for floor = lo, hi do
        local list = EF.fightsOn(floor)
        local pick = {}
        for _, f in ipairs(list) do
            if f.kind == "combat" and Dressing.eligible({ id = f.id, kind = "combat" }) then pick[#pick + 1] = f end
        end
        table.sort(pick, function(a, b)
            if (a.weight or 1) ~= (b.weight or 1) then return (a.weight or 1) > (b.weight or 1) end
            return tostring(a.id) < tostring(b.id)
        end)
        for i = 1, math.min(per, #pick) do fights[#fights + 1] = pick[i] end
    end
    local trials = sample(fights, seeds)
    print(string.format("DRESSING COST -- %d fights (floors %d-%d, %d a floor), %d seeds each, dice live",
        #fights, lo, hi, per, seeds))
    for _, f in ipairs(fights) do print(string.format("  floor %d  %s", f.floor, f.id)) end

    local function play(v)
        local rows = {}
        for _, t in ipairs(trials) do
            local ok, r = pcall(trial, t.f, t.seed, v)
            if ok then rows[t.key] = r
            else print(string.format("  ERROR %s %s on %s: %s", v.kind, tostring(v.id or v.k), tostring(t.f.id), tostring(r))) end
        end
        return rows
    end
    local function summary(rows)
        local n, win, cost, turns, und = 0, 0, 0, 0, 0
        for _, r in pairs(rows) do
            if r.applied then
                n = n + 1
                win, cost, turns = win + r.win, cost + r.cost, turns + r.turns
                if r.undecided then und = und + 1 end
            end
        end
        if n == 0 then return 0, 0, 0, 0, 0 end
        return n, win / n, cost / n, turns / n, und
    end

    local base = play({ kind = "base" })
    -- The noise floor: the undressed sample again, in the same process.
    local again = play({ kind = "base" })
    local same, total = 0, 0
    for key, r in pairs(again) do
        total = total + 1
        if base[key] and math.abs(base[key].cost - r.cost) < 1e-9 and base[key].turns == r.turns then same = same + 1 end
    end
    local repMean, repSe = paired(again, base, "cost")
    local n0, w0, c0, t0 = summary(base)
    print("")
    print(string.format("BASE: %d trials, win %.1f%%, cost %.3f, turns %.1f", n0, w0 * 100, c0, t0))
    print(string.format("REPEAT (same seeds, same process): %d/%d trials identical, cost delta %+.4f +/- %.4f",
        same, total, repMean, repSe))

    -- The ruler.
    local curve = {}
    print("")
    print("RULER (enemy stats scaled):")
    for _, k in ipairs(M.SCALES) do
        local rows = play({ kind = "scale", k = k })
        local rsum, rn = 0, 0
        for _, r in pairs(rows) do rsum, rn = rsum + r.ratio, rn + 1 end
        local x = rn > 0 and (rsum / rn - 1) or k
        local dy, se = paired(rows, base, "cost")
        local dw = paired(rows, base, "win")
        local dt = paired(rows, base, "turns")
        local _, wn = summary(rows)
        print(string.format("  stats +%2.0f%%  worth +%5.1f%%  win %5.1f%% (%+5.1f)  cost %+.4f +/- %.4f  turns %+5.1f",
            k * 100, x * 100, wn * 100, dw * 100, dy, se, dt))
        curve[#curve + 1] = { x, dy }
    end

    local variants = {}
    if not only or only == "affix" then
        for _, id in ipairs(Affix.ids()) do variants[#variants + 1] = { kind = "affix", id = id } end
    end
    if not only or only == "condition" then
        for _, id in ipairs(Condition.ids()) do variants[#variants + 1] = { kind = "condition", id = id } end
    end
    if not only or only == "objective" then
        for _, id in ipairs(Dressing.KINDS) do variants[#variants + 1] = { kind = "objective", id = id } end
    end

    print("")
    print(string.format("  %-28s %5s %7s %8s %18s %7s %16s %6s", "dressing", "n", "win", "dWin", "dCost", "dTurns",
        "worth k", "mult"))
    local priced = {}
    for _, v in ipairs(variants) do
        local rows = play(v)
        local n, wn = summary(rows)
        if n == 0 then
            print(string.format("  %-28s never applied", v.id))
        else
            local dy, se = paired(rows, base, "cost")
            local dw = paired(rows, base, "win")
            local dt = paired(rows, base, "turns")
            local k, slope = invert(curve, dy)
            local kse = slope > 0 and se / slope or 0
            local mult = 1 + k
            -- Inside the noise: priced at its noise would be a number about the dice.
            if math.abs(dy) < 2 * se then mult = 1 end
            mult = math.max(0.5, math.min(3, math.floor(mult * 20 + 0.5) / 20))
            priced[#priced + 1] = { v = v, mult = mult, dy = dy, se = se, dw = dw, n = n }
            print(string.format("  %-28s %5d %6.1f%% %+7.1f %+.4f +/- %.4f %+7.1f %+6.3f +/- %.3f %6.2f",
                v.id, n, wn * 100, dw * 100, dy, se, dt, k, kse, mult))
        end
    end

    print("")
    print("-- paste into Muster.DRESSING (models/muster.lua):")
    for _, kind in ipairs({ "affix", "condition", "objective" }) do
        print(string.format("    %s = {", kind))
        for _, p in ipairs(priced) do
            if p.v.kind == kind then
                print(string.format("        %s = %.2f, -- dCost %+.3f +/- %.3f, dWin %+.1f pts, n %d",
                    (p.v.id ~= "break" and p.v.id:match("^[%a_]+$")) and p.v.id or ('["' .. p.v.id .. '"]'), p.mult, p.dy, p.se, p.dw * 100, p.n))
            end
        end
        print("    },")
    end
end

return M
