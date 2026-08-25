-- Tests for the PROGRAMMATIC ANIMATION SET (ui/combat_fx.lua) -- the six clips a Spine rig would have
-- carried (idle, move, attack, hit, cast, death), authored instead as transform curves over a flat
-- token because a unit drawn at ~52px cannot show skeletal deformation anyway.
--
-- Almost all of the set is a matter of taste and belongs in front of eyes, not an assertion. What is
-- NOT a matter of taste, and is what every case below guards, is the handful of claims the curves are
-- built on -- each one of which fails silently and looks merely "a bit off" rather than broken:
--
--   * idle answers to no cue, so it must reach a unit that has never acted (no reaction record).
--   * idle phase is per-unit, or the whole army breathes in lockstep -- the single tell that gives a
--     procedural idle away.
--   * the attack pulls BACK before it commits, which is the whole difference from the symmetric
--     out-and-back this replaced.
--   * a hit recoils AWAY from its attacker, measured against the tile the body is still drawn on --
--     not the one a shove has already moved it to.
--   * squash conserves volume: a scale down on one axis is paid for on the other.
--   * every animation resolves to the identity transform once its clip is over.

local CombatFx = require("ui.combat_fx")

-- :new() builds two fonts, and love.graphics.newFont refuses to work without a window (see
-- tests/combat_fx_spec.lua, which stubs it the same way).
local function newFx()
    local gfx = love.graphics
    local real = gfx.newFont
    gfx.newFont = function() return { getHeight = function() return 18 end } end
    local ok, fx = pcall(CombatFx.new)
    gfx.newFont = real
    assert(ok, "could not construct CombatFx: " .. tostring(fx))
    return fx
end

local function unit(x, y, name)
    return { x = x, y = y, char = { name = name or "body", stats = { health = { current = 20, max = 20 } } } }
end

local TILE = 60
local STEP = 1 / 60

-- Run the controller forward `secs` and hand back the state at the end.
local function advance(fx, secs)
    for _ = 1, math.floor(secs / STEP + 0.5) do fx:update(STEP) end
end

-- Sample one unit's transform over `secs`, one entry per frame.
local function sample(fx, u, secs)
    local out = {}
    for _ = 1, math.floor(secs / STEP + 0.5) do
        local ox, oy, _, _, rot, sx, sy = fx:spriteState(u, TILE)
        out[#out + 1] = { ox = ox, oy = oy, rot = rot, sx = sx, sy = sy }
        fx:update(STEP)
    end
    return out
end

local function extreme(list, key)
    local lo, hi = math.huge, -math.huge
    for _, f in ipairs(list) do
        if f[key] < lo then lo = f[key] end
        if f[key] > hi then hi = f[key] end
    end
    return lo, hi
end

return {
    {
        name = "idle reaches a unit that has never acted, and never stands perfectly still",
        fn = function()
            local fx = newFx()
            local u = unit(3, 3)
            -- No ingest, no cue, no reaction record -- the case the old spriteState answered with a
            -- flat 0,0,0,0 and which left a board of untouched units reading as a set of counters.
            assert(fx.units[u] == nil, "the unit under test must have no reaction record")

            local frames = sample(fx, u, 2.4) -- past one full breath (IDLE_PERIOD)
            local loY, hiY = extreme(frames, "oy")
            assert(hiY - loY > 0.4, "an idling unit never moved: " .. tostring(hiY - loY) .. "px of breath")
            local loS, hiS = extreme(frames, "sy")
            assert(hiS - loS > 0.01, "an idling unit never swelled")
            local loR, hiR = extreme(frames, "rot")
            assert(hiR - loR > 0.01, "an idling unit never swayed")
            -- It FLOATS: the breath lifts the body off its foot line and never drives it through it.
            assert(hiY <= 0.001, "the idle breath pushed a body below its own feet")
        end,
    },
    {
        name = "idle phase is per unit -- a rank of bodies does not breathe in lockstep",
        fn = function()
            local fx = newFx()
            local rank = {}
            for i = 1, 6 do rank[i] = unit(i, 1) end

            -- Sample the whole rank on the same frame, the way the board draws it.
            local ys = {}
            for i, u in ipairs(rank) do
                local _, oy = fx:spriteState(u, TILE)
                ys[i] = oy
            end
            local lo, hi = math.huge, -math.huge
            for _, y in ipairs(ys) do lo = math.min(lo, y); hi = math.max(hi, y) end
            assert(hi - lo > 0.3,
                "six bodies drawn on one frame shared a breath position -- the idle is in lockstep")

            -- And the phase is STABLE: looking at a unit again does not restart its breath.
            local before = select(2, fx:spriteState(rank[1], TILE))
            local again = select(2, fx:spriteState(rank[1], TILE))
            assert(math.abs(before - again) < 1e-9, "a unit's idle phase changed between two reads")

            -- Deterministic across controllers: same order in, same phases out (no clock, no random).
            local fx2 = newFx()
            local rank2 = {}
            for i = 1, 6 do rank2[i] = unit(i, 1) end
            for i = 1, 6 do
                local _, oy = fx2:spriteState(rank2[i], TILE)
                assert(math.abs(oy - ys[i]) < 1e-9, "idle phase is not deterministic at index " .. i)
            end
        end,
    },
    {
        name = "the attack gathers backward before it commits",
        fn = function()
            local fx = newFx()
            local attacker, target = unit(2, 2, "attacker"), unit(3, 2, "target")
            fx:lunge(attacker, target)

            local frames = sample(fx, attacker, 0.26) -- LUNGE_TIME
            local lo, hi = extreme(frames, "ox")
            -- The target is to the RIGHT, so the strike is +x and the anticipation is -x. A symmetric
            -- out-and-back -- what this replaced -- would never produce a negative sample.
            assert(lo < -0.5, "the swing never pulled back: minimum x offset was " .. tostring(lo))
            assert(hi > 8, "the swing never extended: maximum x offset was " .. tostring(hi))
            assert(hi > -lo * 2, "the wind-up outweighed the strike it was gathering for")

            -- Order matters as much as presence: the pull happens BEFORE the extension.
            local iLo, iHi
            for i, f in ipairs(frames) do
                if f.ox == lo then iLo = i end
                if f.ox == hi and not iHi then iHi = i end
            end
            assert(iLo < iHi, "the body extended before it gathered")

            -- ...and the follow-through is the longest phase: more of the clip is spent coming home
            -- than getting there, which is where the weight of a swing lives.
            assert(#frames - iHi > iHi, "the recovery was shorter than the strike")
        end,
    },
    {
        name = "a hit recoils away from its attacker, off the tile the body is drawn on",
        fn = function()
            local fx = newFx()
            local attacker, victim = unit(2, 2, "attacker"), unit(3, 2, "victim")
            fx:hit(victim, 10, false, attacker)

            local ox = fx:spriteState(victim, TILE)
            assert(ox > 1, "a struck body did not recoil away from its attacker (dx " .. tostring(ox) .. ")")

            -- The shove case: the model has ALREADY put the body two tiles right, but it is still
            -- being drawn on tile 3. Measured against unit.x it would recoil off the wrong tile --
            -- here the line is (cell 3) - (attacker 2), so the throw is still +x.
            local fx2 = newFx()
            local shoved = unit(5, 2, "shoved") -- model position: already knocked back
            fx2:hit(shoved, 10, false, attacker, { x = 3, y = 2 })
            local ox2 = fx2:spriteState(shoved, TILE)
            assert(ox2 > 1, "the recoil was measured off the destination tile, not the struck one")

            -- A heavier blow throws the body further -- the same clip says how bad it was.
            local light, heavy = newFx(), newFx()
            local lv, hv = unit(3, 2), unit(3, 2)
            light:hit(lv, 2, false, attacker)
            heavy:hit(hv, 40, false, attacker)
            assert(heavy:spriteState(hv, TILE) > light:spriteState(lv, TILE) + 1,
                "a heavy blow recoiled no harder than a scratch")
        end,
    },
    {
        name = "damage with no attacker still reacts -- there is just no direction to recoil along",
        fn = function()
            -- A Burn tick, a hazard, a trap: models/combat.lua deals these with no attacker at all, so
            -- the directional recoil cannot fire and the direction-blind jitter has to still be there.
            local fx = newFx()
            local u = unit(4, 4)
            fx:hit(u, 6, false)
            assert(fx.units[u].knockT == nil, "a hazard tick invented an attacker to recoil from")

            local frames = sample(fx, u, 0.26) -- SHAKE_TIME
            local lo, hi = extreme(frames, "ox")
            assert(hi - lo > 2, "a body burned by nothing in particular did not react at all")
        end,
    },
    {
        name = "squash conserves volume, on every clip that squashes",
        fn = function()
            -- A scale down on one axis paid for on the other. Skip it and a squashed body just reads
            -- as a smaller body, which is the difference between weight and a glitch.
            local checks = {
                { name = "hit", set = function(fx, u) fx:hit(u, 20, false, unit(2, 4)) end, secs = 0.30 },
                { name = "attack", set = function(fx, u) fx:lunge(u, unit(6, 4)) end, secs = 0.26 },
                { name = "cast", set = function(fx, u) fx:cast(u, 6, 4, false, false) end, secs = 0.30 },
            }
            for _, c in ipairs(checks) do
                local fx = newFx()
                local u = unit(4, 4)
                c.set(fx, u)
                local frames = sample(fx, u, c.secs)
                local opposed = false
                for _, f in ipairs(frames) do
                    -- Off the identity in opposite directions on the same frame, somewhere in the clip.
                    if (f.sx - 1) * (f.sy - 1) < -1e-4 then opposed = true end
                    assert(f.sx > 0.5 and f.sy > 0.5, c.name .. " collapsed the body to nothing")
                    assert(f.sx < 1.6 and f.sy < 1.6, c.name .. " inflated the body")
                end
                assert(opposed, c.name .. " scaled both axes the same way -- it resizes, it does not squash")
            end
        end,
    },
    {
        name = "the death collapse accelerates, sinks, and goes down on the side it was struck from",
        fn = function()
            local fx = newFx()
            local attacker, victim = unit(2, 2, "attacker"), unit(3, 2, "victim")
            fx:hit(victim, 30, true, attacker) -- struck from the LEFT: thrown right, falls right
            fx:ingest({ { type = "death", unit = victim, beat = 0 } }, attacker)

            local frames = sample(fx, victim, 0.5) -- inside DEATH_TIME
            local last = frames[#frames]
            assert(last.rot > 0.05, "a felled body never went over (rot " .. tostring(last.rot) .. ")")
            assert(last.oy > 0, "a felled body never settled")
            assert(last.sy < 1, "a felled body never gave way")

            -- Accelerating, not eased: the second half of the fall covers more ground than the first.
            local mid = frames[math.floor(#frames / 2)]
            assert(last.rot - mid.rot > mid.rot - frames[1].rot,
                "the collapse decelerated -- a killed body gives way, it does not lower itself")

            -- Struck from the RIGHT instead, it goes down the other way.
            local fx2 = newFx()
            local v2 = unit(3, 2, "victim")
            fx2:hit(v2, 30, true, unit(5, 2, "attacker"))
            fx2:ingest({ { type = "death", unit = v2, beat = 0 } }, nil)
            advance(fx2, 0.5)
            local rot2 = select(5, fx2:spriteState(v2, TILE))
            assert(rot2 < 0, "both bodies toppled the same way regardless of where the blow came from")
        end,
    },
    {
        name = "every clip resolves to the identity transform once it is over",
        fn = function()
            -- Anything that does not settle exactly leaves a body permanently leaning or scaled, which
            -- accumulates over a battle and reads as art that was authored wrong.
            local fx = newFx()
            local a, b = unit(2, 2, "a"), unit(3, 2, "b")
            fx:lunge(a, b)
            fx:hit(b, 12, false, a)
            fx:cast(a, 3, 2, false, false)
            fx:setSlide(b, 4, 2, 0.2)
            advance(fx, 1.2) -- past every clip in the set

            for _, u in ipairs({ a, b }) do
                local r = fx.units[u]
                assert(not (r.lungeT or r.castT or r.shakeT or r.knockT or r.slideT), "a clip never ended")
                -- Idle is still running, so the transform is not the identity -- it is the identity
                -- PLUS one breath. Check against that budget rather than against zero.
                local ox, oy, _, _, rot, sx, sy = fx:spriteState(u, TILE)
                assert(math.abs(ox) < 0.001, "a settled body held a horizontal offset: " .. tostring(ox))
                assert(oy <= 0.001 and oy > -0.06 * TILE, "a settled body held a vertical offset: " .. tostring(oy))
                assert(math.abs(rot) < 0.05, "a settled body held a lean: " .. tostring(rot))
                assert(math.abs(sx - 1) < 0.05 and math.abs(sy - 1) < 0.05, "a settled body held a scale")
            end
            assert(not fx:busy(), "the controller never released the turn hand-off")
        end,
    },
    {
        name = "the walk leans the way the player sees it going, and stands still between steps",
        fn = function()
            local fx = newFx()
            local u = unit(5, 2) -- arrived here from tile 2, travelling screen-right
            fx:setSlide(u, 2, 2, 0.3)
            local frames = sample(fx, u, 0.3)
            local lo, hi = extreme(frames, "rot")
            assert(hi > 0.02, "a body walking right never leaned into it")
            assert(math.abs(lo) < 0.02, "a body walking right leaned backward at some point")

            -- Footfalls: the hop crosses its own baseline more than once per tile, so the step reads
            -- as two contacts rather than one long bounce.
            local crossings, prev = 0, nil
            for _, f in ipairs(frames) do
                local above = f.oy < -0.5
                if prev ~= nil and above ~= prev then crossings = crossings + 1 end
                prev = above
            end
            assert(crossings >= 3, "the walk hopped once per tile -- that reads as a bounce, not a step")

            -- Once home, the walk stops contributing entirely (the idle takes back over).
            advance(fx, 0.4)
            local _, _, _, _, rot = fx:spriteState(u, TILE)
            assert(math.abs(rot) < 0.05, "a body that had stopped walking kept its lean")
        end,
    },
}
