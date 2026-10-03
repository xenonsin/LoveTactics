-- THE MANY FACED ONE: Envy's general, and the sovereign of the Faceless (data/characters/character_general_envy.lua).
-- Reviewed over three rounds, 2026-10-01..03 ("Envy's Bestiary", the general's rows). The face every Faceless
-- envies: its soldiers wear soldiers, and it wears GENERALS.
--
-- THE FORMS. It wears, in turn, the general of every circle ABOVE Envy in this run, in the order the company met
-- them -- Gula, Luxuria, Avaritia, Furor and Acedia on the authored way down (Descent.INFERNO). Each form is that
-- general's real body and kit, worn through Faces.wear (the transform the pig and the bear use, carrying the
-- body's organs), with its signature openers fired as it is put on. A shuffled campaign can deal Envy early, with
-- fewer generals above it, and then the forms are topped up from the circles BELOW it in the same run's order, to
-- FORMS: it envies what you have not reached yet.
--
-- ONE BAR, IN EQUAL SHARES (approved option A). The bar is cut into one share per form plus one for the split, and
-- dropping through a share moves to the next stage. The shares only run forward: a heal back over a line does not
-- put an old face back on, and a blow that crosses two lines skips the form between them.
--
-- REDUCED, ON PURPOSE ("their health could be reduced so the fights are not just repeats of all the floors"). The
-- blueprint's 540 is six shares of 90, so a form holds about three-eighths of the 220-380 its general holds on her
-- own stair. Each form is that fight, shortened: the kit, the escort and the waves, at a third of the length.
--
-- EACH FORM CALLS ITS STAIR'S ADDS. Its escort (Descent.SINS' `guardian.filler`), its swarm (the lieutenant's
-- filler, as Descent.guardList seats it) and its waves (Descent.stairWin's copy of `guardian.waves`, re-timed from
-- now). Board features that live in a stair's ground do not come with it -- Avaritia's hoard heaps (her opener is
-- skipped), her eggs, Gula's wood -- so those forms fight with their kit and their adds only.
--
-- THE COURT SHAPESHIFTS (revised by the author). When a form breaks, every add still standing becomes the next
-- form's add, role for role: the escort becomes the new escort, the swarm the new swarm. A shift is a transform,
-- so the body keeps its place and its turn, and keeps the SHARE of its health it had left.
--
-- THE SPLIT. With the last form broken it splits into an exact copy of each body in the company -- items, stats
-- and tactics -- one of them worn by itself and the rest fielded beside it, every one on the same health pool
-- (Summon's `sharePool`, by reference): a blow on any copy comes off the one bar, and when it empties every copy
-- falls at once (status_split).
--
-- The rules ride on a STATUS (status_many_faced) rather than a trait, for the reason status_faceless does: a trait
-- lives in the grid and a form swaps the grid. The opener alone rides the organ (trait_the_many_faced).
--
-- Pure logic (no love.graphics), so it loads under the headless tests.

local Character = require("models.character")

local ManyFaced = {}

ManyFaced.ID = "character_general_envy"
ManyFaced.SIN = "envy"
ManyFaced.FORMS = 5 -- the authored count: the five circles above Envy on the way down
ManyFaced.STATUS = "status_many_faced"
ManyFaced.SPLIT = "status_split"

-- Openers NOT fired as a form is put on. A Thousand Faces and the general's own rule are what this body is, not
-- what the form brings; the Hoard lays heaps on the ground, and a stair's ground does not come with its general.
ManyFaced.SKIP_OPENERS = {
    trait_a_thousand_faces = true,
    trait_the_many_faced = true,
    trait_the_hoard = true,
}

local function sinById(id)
    for _, sin in ipairs(require("models.descent").SINS) do
        if sin.id == id then return sin end
    end
end
ManyFaced.sinById = sinById

-- The circles of `run`, in the order they are met, as ids. With no run handed in, the save being played (its
-- descent); with none of those, the authored order.
function ManyFaced.runOrder(run)
    local Descent = require("models.descent")
    if run == nil then
        local ok, Player = pcall(require, "models.player")
        local p = ok and Player and Player.active
        run = p and p.descentRun or nil
    end
    local out = {}
    for _, sin in ipairs(Descent.sinOrder(run and run.seed, run and run.shuffled)) do out[#out + 1] = sin.id end
    return out
end

-- The circles whose generals it wears, in order: every circle above Envy, then -- only when that is fewer than
-- FORMS -- the circles below it, nearest first.
function ManyFaced.formsFor(order, n)
    n = n or ManyFaced.FORMS
    local at
    for i, id in ipairs(order) do if id == ManyFaced.SIN then at = i end end
    local forms, below = {}, {}
    for i, id in ipairs(order) do
        if id ~= ManyFaced.SIN then
            if at and i > at then below[#below + 1] = id else forms[#forms + 1] = id end
        end
    end
    for _, id in ipairs(below) do
        if #forms >= n then break end
        forms[#forms + 1] = id
    end
    return forms
end

-- One share per form, plus the split's.
function ManyFaced.shares(unit)
    local st = unit and unit.manyFaced
    return ((st and #st.forms) or ManyFaced.FORMS) + 1
end

-- Which stage a bar at `current` of `max` stands in: 1 at full, `shares` in the last share.
function ManyFaced.stageAt(current, max, shares)
    if not (max and max > 0) then return 1 end
    local left = math.ceil((current or 0) * shares / max - 1e-9)
    return math.max(1, math.min(shares, shares - left + 1))
end

-- A form's share as a bar of its own, so a general's own half-health rules (her phases, the Court's quickening)
-- read the form rather than the whole of the sovereign. Nil outside a form.
function ManyFaced.formFraction(unit)
    local bar = unit and unit.formBar
    if not bar then return nil end
    local hp = unit.char.stats.health
    local span = bar.top - bar.floor
    if span <= 0 then return 0 end
    return math.max(0, math.min(1, ((hp.current or 0) - bar.floor) / span))
end

-- Who a stair seats beside its general: its escort, and the swarm behind it (Descent.guardList's own rule).
function ManyFaced.addsOf(sin)
    local band = sin.guardian
    local named = sin.minor and sin.minor.escortsGeneral ~= false and sin.minor.filler or nil
    return band.filler, named or band.filler
end

-- Its court: everything standing on its side that it did not conjure as a copy, and nothing it holds by a
-- charm from the other side (a company member it took is the company's, not a face).
local function court(combat, unit)
    local out = {}
    for _, u in ipairs(combat.units or {}) do
        if u.alive and u ~= unit and u.side == unit.side and not u.summoned and not u.timeless
            and not u._charmSide and not u.manyFacedOf then
            out[#out + 1] = u
        end
    end
    return out
end

local function levelOf(u)
    local Transform = require("models.transform")
    local own = Transform.originalChar(u) or u.char
    return own.level or u.char.level or 1
end

-- One add becomes `id`, keeping its tile, its turn and the share of its health it had left.
function ManyFaced.shift(combat, u, id)
    local Transform = require("models.transform")
    if not (u and u.alive and Character.defs[id]) then return nil end
    if Transform.isTransformed(u) then Transform.revert(combat, u) end
    if u.char.id == id then return u.char end
    local hp = u.char.stats.health
    local frac = (hp.max and hp.max > 0) and (hp.current / hp.max) or 1
    local level = levelOf(u)
    local shape = Transform.apply(combat, u, id, { level = level })
    if not shape then return nil end
    local fresh = require("models.growth").atLevel(id, level).stats.health
    local max = (type(fresh) == "table" and fresh.max) or hp.max
    shape.stats.health = { max = max, current = math.max(1, math.floor(max * frac + 0.5)) }
    return shape
end

-- The waves a form's stair fields, re-timed from now. Only a wave battle takes them: on a plain kill-them-all the
-- adds would make the fight one nobody can finish.
local function installWaves(combat, sin)
    local obj = combat.objective
    if not (obj and obj.type == "assassinate") then return end
    local waves = {}
    local win = sin and require("models.descent").stairWin(sin, true)
    for i, w in ipairs((win and win.waves) or {}) do
        local copy = {}
        for k, v in pairs(w) do copy[k] = v end
        copy.at = (combat.clock or 0) + (w.at or w.every or 0)
        waves[i] = copy
    end
    obj.waves = waves
    combat.waveState = {}
    combat._courtQuickened = nil
end

-- Take the old form off cleanly: what it held goes back, what it wore on itself goes with it. The company's
-- debuffs on it stay -- a Burn does not care whose face it is burning.
local function leaveForm(combat, unit)
    local Status = require("models.status")
    local Combat = require("models.combat")
    for _, u in ipairs(combat.units or {}) do
        if u.alive and u ~= unit then
            local charm = Status.get(u, "status_charm")
            if charm and charm.charmer == unit then
                -- A bound add stays to be re-cast rather than walking out; a taken company member goes home.
                charm.bound = nil
                Status.remove(combat, u, "status_charm")
                if u.guard and u.guard.ward == unit then u.guard = nil end
            end
            if u.swallowedBy == unit then Combat.disgorge(combat, u) end
        end
    end
    local keep = { [ManyFaced.STATUS] = true, [ManyFaced.SPLIT] = true,
        [require("models.faces").STATUS] = true }
    local snapshot = {}
    for _, s in ipairs(unit.statuses or {}) do snapshot[#snapshot + 1] = s end
    for _, s in ipairs(snapshot) do
        if not keep[s.id] and not (s.def and s.def.debuff) then Status.remove(combat, unit, s.id) end
    end
end

-- Call one escort beside it when none of its court stands in that role.
local function callEscort(combat, unit, escortId)
    local Combat = require("models.combat")
    for _, u in ipairs(court(combat, unit)) do
        if u.courtRole == "escort" then return nil end
    end
    local def = Character.defs[escortId]
    if not def then return nil end
    local fp = def.footprint or {}
    local x, y = Combat.openBlockNear(combat, unit.x, unit.y, fp.w or 1, fp.h or 1, { radius = 3 })
    if not x then return nil end
    local char = require("models.growth").atLevel(escortId, levelOf(unit))
    local u = Combat.addUnit(combat, char, unit.side, x, y)
    u.courtRole = "escort"
    Combat.logEvent(combat, "action", string.format("%s joins the fight!", char.name or "An escort"), u)
    Combat.enterTile(combat, u, x, y)
    return u
end

local function wearForm(combat, unit, sin)
    local Faces = require("models.faces")
    local shape = Faces.wear(combat, unit, sin.guardian.lead)
    if shape then shape.boss = true end
    return shape
end

-- Put on stage `stage`: a form, or the split past the last one.
function ManyFaced.enter(combat, unit, stage, opening)
    local st = unit.manyFaced
    st.stage = stage
    if stage > #st.forms then return ManyFaced.split(combat, unit) end
    local Combat = require("models.combat")
    local sin = sinById(st.forms[stage])
    if not opening then leaveForm(combat, unit) end
    wearForm(combat, unit, sin)
    local shares = ManyFaced.shares(unit)
    local max = unit.char.stats.health.max
    unit.formBar = { top = max * (shares - stage + 1) / shares, floor = max * (shares - stage) / shares }

    local escortId, swarmId = ManyFaced.addsOf(sin)
    for _, u in ipairs(court(combat, unit)) do
        ManyFaced.shift(combat, u, u.courtRole == "escort" and escortId or swarmId)
        u.courtRole = u.courtRole or "swarm"
    end
    if not opening then callEscort(combat, unit, escortId) end
    installWaves(combat, sin)
    Combat.logEvent(combat, "status", string.format("The Many Faced One wears %s.",
        unit.char.name or sin.name), unit)
    -- The form's own openers, as if this were her bell: the Court kneels, the oath is sworn.
    require("models.trait").fire(combat, unit, "onCombatStart", {}, function(t)
        return not ManyFaced.SKIP_OPENERS[t.id]
    end)
    return unit.char
end

-- An exact copy of a company member's body, tactics included -- Summon.copyChar carries the items and the stats,
-- and a copy that is to FIGHT like you also needs your rule list.
local function copyOf(src)
    local char = require("models.summon").copyChar(src)
    char.ai, char.aiRules, char.archetype = src.ai, src.aiRules, src.archetype
    char.boss = true -- what it is underneath is still the sovereign: no execute, no Charm
    return char
end

function ManyFaced.split(combat, unit)
    local st = unit.manyFaced
    local Combat = require("models.combat")
    local Status = require("models.status")
    local Summon = require("models.summon")
    leaveForm(combat, unit)
    installWaves(combat, nil)
    st.split = true
    unit.formBar = nil
    local company = {}
    for _, u in ipairs(combat.units or {}) do
        if u.alive and u.side ~= unit.side and not u.summoned and not u.timeless then company[#company + 1] = u end
    end
    if #company == 0 then return nil end

    st.splitFace = copyOf(company[1].char)
    require("models.faces").wear(combat, unit, st.splitFace)
    Status.apply(combat, unit, ManyFaced.SPLIT, { applier = unit })
    local copies = { unit }
    for i = 2, #company do
        local x, y = Combat.openBlockNear(combat, unit.x, unit.y, 1, 1, { radius = 3 })
        if x then
            local copy = Summon.copyOf(combat, unit, company[i], x, y, { sharePool = true })
            if copy and copy.alive then
                local src = company[i].char
                copy.char.ai, copy.char.aiRules, copy.char.archetype = src.ai, src.aiRules, src.archetype
                copy.char.boss = true
                copy.manyFacedOf = unit
                Status.apply(combat, copy, ManyFaced.SPLIT, { applier = unit })
                copies[#copies + 1] = copy
            end
        end
    end
    Combat.logEvent(combat, "status", "The Many Faced One splits into a copy of each of you, on one health pool.",
        unit)
    return copies
end

-- AT THE BELL (trait_the_many_faced): its own forms, chosen by its own rule, never by Reshape.
function ManyFaced.open(combat, unit, order)
    if not (combat and unit and unit.alive) or unit.manyFaced then return nil end
    unit.faceLocked = true
    unit.faceHand = unit.faceHand or {}
    local forms = ManyFaced.formsFor(order or ManyFaced.runOrder())
    unit.manyFaced = { forms = forms, stage = 1 }
    require("models.status").apply(combat, unit, ManyFaced.STATUS, { applier = unit })
    if #forms == 0 then return nil end
    -- The court on the board at the bell: the first of them is the escort, the rest the swarm, as the stair
    -- seated them (Descent.guardList).
    local envy = sinById(ManyFaced.SIN)
    local escortAt = envy and envy.guardian.filler
    local list = court(combat, unit)
    local escort
    for _, u in ipairs(list) do if not escort and u.char.id == escortAt then escort = u end end
    escort = escort or list[1]
    for _, u in ipairs(list) do u.courtRole = (u == escort) and "escort" or "swarm" end
    return ManyFaced.enter(combat, unit, 1, true)
end

-- A WOUND (status_many_faced's onDamaged): through a share, into the next stage.
function ManyFaced.onDamaged(combat, unit)
    local st = unit and unit.manyFaced
    if not (st and unit.alive) or st.split then return nil end
    local hp = unit.char.stats.health
    local stage = ManyFaced.stageAt(hp.current, hp.max, ManyFaced.shares(unit))
    if stage > st.stage then return ManyFaced.enter(combat, unit, stage) end
    return nil
end

-- THE TOP OF ITS TURN: a body stripped of its shape (Unmasking Powder) puts the stage's face back on. Nothing else
-- comes back with it: no adds, no openers.
function ManyFaced.onTurnStart(combat, unit)
    local st = unit and unit.manyFaced
    if not (st and unit.alive) then return nil end
    if require("models.transform").isTransformed(unit) then return nil end
    if st.split then
        if st.splitFace then return require("models.faces").wear(combat, unit, st.splitFace) end
        return nil
    end
    local sin = sinById(st.forms[st.stage] or "")
    if sin then return wearForm(combat, unit, sin) end
    return nil
end

-- ONE POOL, ONE DEATH (status_split's onDeath): a body on an empty shared pool takes every other body on it down.
function ManyFaced.onSplitDeath(combat, unit)
    local pool = unit and unit.char and unit.char.stats.health
    if not (combat and type(pool) == "table") or (pool.current or 0) > 0 then return 0 end
    local Combat = require("models.combat")
    local n = 0
    for _, u in ipairs(combat.units or {}) do
        if u ~= unit and u.alive and u.char and u.char.stats.health == pool then
            if Combat.fell(combat, u, { denyRevival = false }) then n = n + 1 end
        end
    end
    return n
end

return ManyFaced
