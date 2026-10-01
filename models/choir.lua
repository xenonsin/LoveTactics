-- THE CHOIR: the angels of Pride's spire (reviewed 2026-09-30, "Pride's Bestiary"). The rules several angel files
-- share, in one place so the data files stay short and the spec has one module to pin:
--
--   THE DECREE    the Throne's floor-reading attack. Each of its wind-ups lights a PATTERN of tiles around its
--                 body -- the cross, then the rings, then the lines, cycling -- and the light lands, holy, when its
--                 slot comes back round. It rides the ordinary wind-up (Combat.useItem's channel branch), so the
--                 telegraph the board already paints for an enemy Meteor Storm is the one the player reads here,
--                 and resolveChannel is the strike. Choir.decreeCells is the pattern; the count of decrees that
--                 have LANDED picks which one, so the tiles painted at commit are the tiles struck at resolve.
--   THE SENTENCE  every third turn of the Throne's, two of the company are chained (status_sentenced, each naming
--                 the other); ending a turn more than 2 tiles apart hurts both.
--   HOSANNA       at each quarter of its health two Heralds are called, and they arrive as a reinforcement WAVE
--                 (objective.waves), so the board's own muster telegraph marks where they will land and a body
--                 standing on the mark turns one back. Appended to the live fight's objective; a Throne that
--                 falls first retires whatever it had called and not yet landed.
--   THE WHEEL     an Ophan that has a foe beside it turns (AI.preempt): it strikes every adjacent tile, every turn.
--
-- Pure logic, no love.graphics. Combat, Status and Trait are required lazily (combat.lua reaches this module from
-- AI.preempt, and item blueprints read it at load).
local Choir = {}

Choir.KIN = "angel"
Choir.DECREE = "weapon_the_decree"
Choir.PATTERNS = { "cross", "rings", "lines" }
Choir.SENTENCE_EVERY = 3     -- the Throne's turns between chains
Choir.SENTENCE_GAP = 2       -- further apart than this at a turn's end, and both are hurt
Choir.HOSANNA_AT = { 0.75, 0.5, 0.25 }
Choir.HOSANNA_CALL = { "character_herald", "character_herald" }

function Choir.isAngel(unit)
    return unit ~= nil and unit.char ~= nil and unit.char.race == Choir.KIN
end

-- ---------------------------------------------------------------------------------------------- the decree

-- Which pattern the bearer's NEXT decree lights: the count of decrees already landed, cycled.
function Choir.pattern(unit)
    local n = (unit and unit.decrees) or 0
    return Choir.PATTERNS[(n % #Choir.PATTERNS) + 1]
end

-- Does a tile `dx`, `dy` off the bearer's footprint (0 on an axis the footprint spans) sit in `pattern`?
--   cross  the rows and columns the body stands in
--   rings  every second ring out from the body: 2, 4, 6 away (the ring beside it is safe)
--   lines  every third row out from the body, across the whole board: 1, 4, 7 above and below
function Choir.inPattern(pattern, dx, dy)
    if pattern == "cross" then return dx == 0 or dy == 0 end
    if pattern == "rings" then
        local r = math.max(dx, dy)
        return r >= 2 and r % 2 == 0
    end
    if pattern == "lines" then return dy >= 1 and dy % 3 == 1 end
    return false
end

-- The tiles the bearer's next decree lights: every open board tile in its pattern, its own footprint excluded.
-- `pattern` may be named to ask about one that is not next (the spec does).
function Choir.decreeCells(combat, unit, pattern)
    local arena = combat and combat.arena
    if not (arena and arena.tiles and unit) then return {} end
    pattern = pattern or Choir.pattern(unit)
    local x0, y0 = unit.x, unit.y
    local x1, y1 = x0 + (unit.w or 1) - 1, y0 + (unit.h or 1) - 1
    local out = {}
    for y = 1, arena.rows or #arena.tiles do
        local row = arena.tiles[y]
        for x = 1, arena.cols or (row and #row or 0) do
            local cell = row and row[x]
            local dx = (x < x0 and x0 - x) or (x > x1 and x - x1) or 0
            local dy = (y < y0 and y0 - y) or (y > y1 and y - y1) or 0
            if cell and cell.walkable and not (dx == 0 and dy == 0) and Choir.inPattern(pattern, dx, dy) then
                out[#out + 1] = { x = x, y = y }
            end
        end
    end
    return out
end

-- The decree LANDS (the wind-up resolved): every foe in the lit tiles takes the blow, and the next pattern is
-- queued -- through fx.bank, which a dry-run preview leaves inert, so hovering the cast never turns the cycle.
function Choir.strike(fx)
    for _, u in ipairs(fx.aoeUnits()) do
        if u ~= fx.user and u.alive and u.side ~= fx.user.side then fx.damage(u) end
    end
    fx.bank("decrees", ((fx.user and fx.user.decrees) or 0) + 1)
end

-- -------------------------------------------------------------------------------------------- the sentence

-- The two bodies of `throne`'s foes standing furthest apart, or nil when fewer than two stand.
function Choir.sentencePair(combat, throne)
    local Combat = require("models.combat")
    local foes = {}
    for _, u in ipairs(combat.units or {}) do
        if u.alive and u.side ~= throne.side and not Combat.isOffTile(u) then foes[#foes + 1] = u end
    end
    local a, b, best
    for i = 1, #foes do
        for j = i + 1, #foes do
            local d = Combat.unitGap(foes[i], foes[j])
            if not best or d > best then a, b, best = foes[i], foes[j], d end
        end
    end
    return a, b
end

-- Chain `a` and `b` (status_sentenced on both, each naming the other). The chain is laid by the Throne, so
-- its `opener` is the Throne and the damage it deals is quoted on the status.
function Choir.sentence(combat, throne, a, b, magnitude)
    local Status = require("models.status")
    local sa = Status.apply(combat, a, "status_sentenced", { applier = throne, magnitude = magnitude })
    local sb = Status.apply(combat, b, "status_sentenced", { applier = throne, magnitude = magnitude })
    if sa then sa.partner = b end
    if sb then sb.partner = a end
    return sa ~= nil and sb ~= nil
end

-- --------------------------------------------------------------------------------------------- hosanna

-- Call two Heralds onto the board as a one-shot reinforcement wave due one turn-and-a-bit out, so the muster
-- telegraph (states/battle.lua's spawnWaves) commits it and marks its tiles before it lands. The objective is
-- copied rather than written into, since an arena's objective can be a table a blueprint owns.
function Choir.hosanna(combat, throne)
    if not combat then return nil end
    local Status = require("models.status")
    local obj = combat.objective or { type = "killAll" }
    local copy = {}
    for k, v in pairs(obj) do copy[k] = v end
    local waves = {}
    for i, w in ipairs(obj.waves or {}) do waves[i] = w end
    local wave = {
        at = (combat.clock or 0) + 2 * Status.TICKS_PER_TURN,
        composition = Choir.HOSANNA_CALL,
        hosanna = true, -- a flag, never the unit: an objective is data and may be copied or saved
    }
    waves[#waves + 1] = wave
    copy.waves = waves
    combat.objective = copy
    return wave
end

-- The Throne fell: every Herald it called and that has not yet landed is retired, and counts as arrived, so a
-- cleared board is a won board rather than one waiting on a muster nobody is left to send.
function Choir.silenceHosanna(combat, throne)
    local obj = combat and combat.objective
    if not (obj and obj.waves) then return end
    combat.waveState = combat.waveState or {}
    for i, w in ipairs(obj.waves) do
        local st = combat.waveState[i]
        if w.hosanna and not (st and (st.fires or 0) > 0) then
            w.at = 0
            combat.waveState[i] = { fires = 1, nextAt = math.huge }
        end
    end
end

-- ---------------------------------------------------------------------------------------------- the plan

-- The angels' compulsions, asked from AI.preempt. The company's own bodies are never compelled.
--   The Throne decrees whenever it is not already holding one.
--   An Ophan with a foe beside it turns.
function Choir.plan(combat, unit)
    if unit.side == "party" or not Choir.isAngel(unit) then return nil end
    local Trait = require("models.trait")
    local Combat = require("models.combat")
    local Character = require("models.character")
    local turns = Trait.flag(unit, "turns")
    local decree, item
    for _, it in ipairs(Character.eachItem(unit.char)) do
        if it.id == Choir.DECREE then decree = it end
        if turns and it.id == turns.def.turns then item = it end
    end
    if decree then
        if unit.channel or Combat.itemBlockReason(unit, decree) then return nil end
        return { item = decree, tx = unit.x, ty = unit.y, reason = "the decree" }
    end
    if not item or Combat.itemBlockReason(unit, item) then return nil end
    for _, u in ipairs(combat.units or {}) do
        if u.alive and u.side ~= unit.side and not Combat.isOffTile(u) and Combat.unitGap(unit, u) == 1 then
            return { item = item, tx = unit.x, ty = unit.y, reason = "the wheel turns" }
        end
    end
    return nil
end

return Choir
