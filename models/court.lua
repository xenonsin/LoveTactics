-- THE COURT: the rules of Luxuria's fight, in one place (data/characters/character_general_lust.lua).
--
-- Settled on review 2026-09-25 (artifact PngKcU4z39bbBGUvodNXHh, rounds queen_r1/queen_r2): Lust's general
-- is a succubus Queen with a large army of charmed followers that protect her, who charms the company
-- "easily but not unfairly". Four pieces of data carry it -- a trait on her vessel (trait_the_court), a
-- rule status she wears (status_the_court), the Consort's badge (status_consort) and her army's waves
-- (Descent.SINS' lust `guardian.waves`) -- and they all reach the same handful of questions, so the
-- questions live here rather than in three copies:
--
--   * WHO IS HER ARMY. Every humanoid on her side, BOUND to her (status_charm with her stamped as the
--     charmer and nothing to revert to -- the Blooded's binding, trait_the_blooded.lua, with no ceiling
--     on how many). She takes the room at the bell and each newcomer at the start of her turn, so a wave
--     that has just walked in fights for her side but is not yet HERS: it guards nothing, shares no
--     wound and does not walk out when she falls, for the turn it takes her to notice it.
--   * HOW THEY PROTECT HER. Each bound body is sworn to her (a declared Oathward, Combat.tryRedirect):
--     standing beside her, it takes the first blow each turn meant for her. And every wound that still
--     reaches her is split across everyone she holds (trait_the_congregation, on her vessel).
--   * HOW MANY OF THE COMPANY SHE MAY HOLD. One while she stands above half her health, two below.
--     The planner already refuses to take a side's last free body (AI.lastFreeBody); this is the
--     ceiling under it that keeps a charm fight from becoming a fight you are not in.
--   * WHAT HALF HEALTH CHANGES. No second body (she is the Queen from the first turn): the cap rises
--     and the Procession quickens.
--   * CHANGING PARTNERS. A foe beside her at the start of her turn, and she is somewhere else: she
--     trades places with one of her own anywhere on the board.
local Status = require("models.status")

local Court = {}

Court.CAP_ABOVE_HALF = 1   -- company members she may hold while above half her health
Court.CAP_BELOW_HALF = 2   -- ...and below it
Court.QUICKEN_EVERY = 40   -- the Procession's period once she is below half (it opens at 60)
Court.GUARD_COOLDOWN = 6   -- the sworn guard's own Oathward cooldown: one blow a turn, as the innate one

local function hpFrac(unit)
    local hp = unit and unit.char and unit.char.stats and unit.char.stats.health
    if not (hp and hp.max and hp.max > 0) then return 1 end
    return (hp.current or 0) / hp.max
end

-- Is `u` one of `me`'s own -- bound, walked on hers? (A company member she TOOK is held, not bound.)
function Court.isThrall(u, me)
    local st = u and Status.get(u, "status_charm")
    return st ~= nil and st.charmer == me and st.bound == true
end

-- The bodies `me` has taken off the far side: a charm she landed that has a side to go back to.
function Court.held(combat, me)
    local out = {}
    for _, u in ipairs(combat.units or {}) do
        local st = u.alive and Status.get(u, "status_charm")
        if st and st.charmer == me and not st.bound and Status.ownSide(u) ~= Status.ownSide(me) then
            out[#out + 1] = u
        end
    end
    return out
end

function Court.cap(me)
    return hpFrac(me) >= 0.5 and Court.CAP_ABOVE_HALF or Court.CAP_BELOW_HALF
end

function Court.belowHalf(me) return hpFrac(me) < 0.5 end

-- Swear `u` to `me`: its guard names her and nobody else. Stashing what it wore before is not needed --
-- a bound body leaves the field when the binding ends (status_charm's onExpire), so it never goes back.
function Court.swear(u, me)
    u.guard = { kind = "oathward", ward = me, cooldown = Court.GUARD_COOLDOWN }
end

-- Take every unclaimed humanoid standing on her side. Returns how many she took. Nearest first, so the
-- log reads in the order the room kneels; the count is uncapped because the army is the fight.
function Court.bind(combat, me)
    if not (me and me.alive) then return 0 end
    local mine = {}
    for _, u in ipairs(combat.units or {}) do
        if u.alive and u ~= me and u.side == me.side
            and u.char and u.char.kind == "humanoid"
            and not Status.get(u, "status_charm") then
            mine[#mine + 1] = u
        end
    end
    local order = {}
    for i, u in ipairs(mine) do order[u] = i end
    table.sort(mine, function(a, b)
        local da = math.max(math.abs(a.x - me.x), math.abs(a.y - me.y))
        local db = math.max(math.abs(b.x - me.x), math.abs(b.y - me.y))
        if da ~= db then return da < db end
        return order[a] < order[b]
    end)
    local took = 0
    for _, u in ipairs(mine) do
        if Status.apply(combat, u, "status_charm", { applier = me, duration = math.huge }) then
            Court.swear(u, me)
            took = took + 1
        end
    end
    return took
end

-- The Procession quickens once she is below half: every recurring wave in the fight's own objective
-- (a copy -- Descent.stairWin never aliases Descent.SINS) re-arms on the shorter period, and a wave
-- already due later than that is pulled in. Once per fight.
function Court.quicken(combat)
    if combat._courtQuickened then return false end
    local waves = combat.objective and combat.objective.waves
    if not waves then return false end
    combat._courtQuickened = true
    local clock = combat.clock or 0
    for i, w in ipairs(waves) do
        if w.every and w.every > Court.QUICKEN_EVERY then
            w.every = Court.QUICKEN_EVERY
            local st = combat.waveState and combat.waveState[i]
            if st and st.nextAt and st.nextAt ~= math.huge and st.nextAt > clock + Court.QUICKEN_EVERY then
                st.nextAt = clock + Court.QUICKEN_EVERY
            end
        end
    end
    return true
end

-- CHANGING PARTNERS. When a foe stands beside her at the start of her turn, trade places with the thrall
-- standing farthest from any foe -- anywhere on the board -- and leave the foe facing it. Returns the
-- thrall she traded with, or nil (nobody beside her, or nobody to trade with).
function Court.changePartners(combat, me)
    local Combat = require("models.combat")
    if not (me and me.alive) then return nil end
    local foes = {}
    local pressed = false
    for _, u in ipairs(combat.units or {}) do
        if u.alive and u.side ~= me.side then
            foes[#foes + 1] = u
            if Combat.unitGap(me, u) == 1 then pressed = true end
        end
    end
    if not pressed then return nil end
    local best, bestGap
    for _, u in ipairs(combat.units or {}) do
        if u.alive and u ~= me and Court.isThrall(u, me) then
            local gap = math.huge
            for _, f in ipairs(foes) do gap = math.min(gap, Combat.unitGap(u, f)) end
            -- Ties go to the first in the roster, so one seed plays one fight.
            if gap > 1 and (not bestGap or gap > bestGap) then best, bestGap = u, gap end
        end
    end
    if not best then return nil end
    if not Combat.swapUnits(combat, me, best) then return nil end
    Combat.logEvent(combat, "action", string.format("%s changes partners with %s.",
        (me.char and me.char.name) or "She", (best.char and best.char.name) or "one of her own"), { me, best })
    return best
end

return Court
