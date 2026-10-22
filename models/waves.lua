-- Waves: the reinforcement schedule of a fight, walked on the fight's own clock.
--
-- MOVED OUT OF states/battle.lua (2026-10-21) so a fight with waves can be run with nobody watching.
-- The schedule was the one part of an objective fight's win clock the model could not advance on its
-- own -- models/encounter_battle.lua refused every such fight from the walk-off for exactly that reason,
-- and no spec could run one either. The battle state still owns the telegraph and the log; this owns
-- WHEN a wave lands and what it lands as. Pure (no love.graphics), so it loads under headless tests.
--
-- objective.waves = { { at = <ticks>, every = <ticks>, count = n, maxAlive = n,
--                       composition = ids|fn, from = <edge descriptor> }, ... }
-- `at` is a mark on the SAME clock the win conditions read, so a wave and a "survive" duration are
-- quoted in one unit -- ticks -- the player already sees everywhere. `from` says which SIDE the wave
-- walks on from (default: behind the enemy line; see Combat.resolveWaveEdge).
--
-- A wave with `every = N` RECURS: it fires every N ticks for as long as the fight lasts, the endless
-- reinforcement a `reach`/`survive` fight wears so it can never be won by attrition
-- (Arena.normalizeObjective synthesizes one). `maxAlive` caps it: while the board already holds that
-- many living enemies the recurrence holds its breath, so it TOPS UP toward a strength rather than
-- piling on without limit. `count` caps the number of firings.
--
-- A wave does not simply appear. LEAD_TICKS before it is due it COMMITS -- Combat.previewWaveArrival
-- resolves its edge, its landing tiles and its roster once, off the live board, and that plan is held
-- on `combat.waveState[i].committed`. The battle state telegraphs the committed plan and the wave
-- fires FROM it, so the marker the player sees and the bodies that land are the same thing. A crowded
-- (`maxAlive`) or retired (`count`) wave drops its commit and shows nothing until it can fire again.
local Combat = require("models.combat")
local Status = require("models.status")

local Waves = {}

Waves.LEAD_TICKS = 2 * Status.TICKS_PER_TURN -- how far ahead a wave commits and starts telegraphing

-- Land a committed plan. A tile somebody has since stepped onto turns that body back rather than
-- stacking two on one cell. Returns the units that arrived.
function Waves.fire(combat, plan)
    local landed = {}
    if not plan then return landed end
    for i, t in ipairs(plan.tiles) do
        local char = plan.chars[i]
        if Combat.footprintFree(combat, t.w, t.h, t.x, t.y) then
            local unit = Combat.addUnit(combat, char, "enemy", t.x, t.y)
            landed[#landed + 1] = unit
            Combat.logEvent(combat, "action",
                string.format("%s joins the fight!", unit.char.name or "A demon"), unit)
        else
            Combat.logEvent(combat, "action",
                string.format("%s is turned back -- the ground is held.", (char and char.name) or "A reinforcement"))
        end
    end
    return landed
end

-- Nothing left to outlast: with the board cleared during a `survive`, the next muster is pulled forward
-- rather than letting the clock run down over an empty field. Without it, killing the wood's last wolf
-- left the player pressing Wait on bare ground until the next wave's tick came round.
local function pullMusterForward(combat, waves, clock)
    local soonest
    for i, wave in ipairs(waves) do
        local st = combat.waveState[i]
        -- A retired wave has nothing left to send, so it is not what the empty board is waiting for.
        if not (wave.count and st.fires >= wave.count) and st.nextAt < math.huge then
            if not soonest or st.nextAt < soonest.nextAt then soonest = st end
        end
    end
    local due = clock + Status.TICKS_PER_TURN
    if soonest and soonest.nextAt > due then soonest.nextAt = due end
end

-- Walk on any wave whose tick has come, and commit any whose lead window has opened. `ctx` is the
-- encounter ctx a `composition(ctx)` scales itself against; `grow` is { level, floor }, so a wave lands
-- at the fight's own level rather than as its bare blueprint. `fire(plan)` lands a plan and defaults to
-- Waves.fire -- the battle state passes its own so the landing is logged and drawn the way it wants.
function Waves.tick(combat, ctx, grow, fire)
    local obj = combat and combat.objective
    local waves = obj and obj.waves
    if not waves then return end
    fire = fire or function(plan) return Waves.fire(combat, plan) end
    combat.waveState = combat.waveState or {}
    local state = combat.waveState
    local clock = combat.clock or 0
    ctx = ctx or {}
    for i, wave in ipairs(waves) do
        -- First fire lands at `at` for a one-shot, at `every` for a recurring wave that gives no
        -- explicit start (so an endless wave holds off one period before its first reinforcement).
        state[i] = state[i] or { fires = 0, nextAt = wave.at or wave.every or 0 }
    end
    if obj.type == "survive" and Combat.aliveCount(combat, "enemy") == 0 then
        pullMusterForward(combat, waves, clock)
    end
    for i, wave in ipairs(waves) do
        local st = state[i]
        local capped = wave.count and st.fires >= wave.count
        local crowded = wave.maxAlive and Combat.aliveCount(combat, "enemy") >= wave.maxAlive
        -- SILENCED: a wave that names the body sending it (`unless`) stops when that body is down -- the
        -- drums stop with the drummer. Read live, so a horn that falls mid-lead-window takes its
        -- committed wave down with it.
        local silenced = wave.unless and not Combat.enemyStanding(combat, wave.unless)
        if capped or crowded or silenced then
            -- Retired, or a top-up wave holding its breath while the board is full: no commit, so no
            -- telegraph and nothing to fire until the board makes room (or, for `count`, ever again).
            st.committed = nil
            if silenced then st.nextAt, st.silenced = math.huge, true end
        elseif clock >= st.nextAt then
            -- Due. Fire from the plan committed in the lead window; if that window was skipped in one
            -- clock jump (a very slow unit's turn elapsing many ticks at once), resolve it in place so
            -- the wave still lands -- just without the early warning.
            fire(st.committed or Combat.previewWaveArrival(combat, wave, ctx, grow))
            st.fires = st.fires + 1
            st.committed = nil
            -- Recurring waves rearm relative to the fire that just happened (so a `maxAlive` stall
            -- doesn't bank up owed waves); a one-shot wave is retired.
            st.nextAt = wave.every and (clock + wave.every) or math.huge
        elseif clock >= st.nextAt - Waves.LEAD_TICKS and not st.committed then
            -- Entering the lead window: resolve the arrival once and HOLD it, so the telegraph is stable
            -- (a random edge is fixed here, not re-rolled every frame) and the spawn reads the same plan.
            st.committed = Combat.previewWaveArrival(combat, wave, ctx, grow)
        end
    end
end

return Waves
