-- ENVY'S ONE-OFF FAMILIES ON THE APPROACH (reviewed 2026-10-01..03, "Envy's Bestiary", rounds 1-3). Seven bodies,
-- each its own family, which is where the Ribstone Waste's creature count comes from. Every rule reads the board
-- it is standing on, so each is the same fight wherever it is met.
--
--   THE EVIL EYE     at the start of its turn it looks at the Fairest, and if it can see that body it sours one of
--                    its blessings into Rattled. It floats.
--   MIRAGE           four identical bodies, three of them illusions: a blow fells one, and their blows land
--                    nothing. Once a round, struck, the real one trades places with an illusion. Illusions weigh
--                    nothing, so only the real one is Mired in quicksand.
--   THE PATCHWORK    whoever last struck it is Conjoined to it, and the stitch moves to each new attacker.
--   SHADE            Unseen while it stands beside a wall or ridge, Limned on open ground; its touch Rattles.
--   JACKAL WEIGHERS  each turn a Weigher sets two of the company on the scale: the lighter heart is Spared, and
--                    every Weigher strikes the heavier, which is Weighed.
--   THE GREEN-EYED   +2 damage for every pair of the company standing side by side, and its roar shoves every
--   MONSTER          such pair apart.
--   SAND-EELS        they go Underground and come up where the Fairest stood, biting whoever is still there.
--
-- THE FAIREST is models/fairest.lua's, the circle's one word for it. A "round" is the body's own turn cycle,
-- because the game has no rounds (models/pride_elites.lua says the same of the Sphinx).
--
-- Pure logic, headless-safe. Combat and Status are reached lazily: models/status.lua and models/combat.lua call
-- into this file at blow time, and this file needs them back.

local Envy = {}

local function Combat() return require("models.combat") end
local function Status() return require("models.status") end

local function nameOf(u) return (u and u.char and u.char.name) or "Unit" end

local function hp(u)
    local h = u and u.char and u.char.stats and u.char.stats.health
    return (type(h) == "table" and h.current) or 0
end

-- The living foes of `unit` that stand on the board.
local function foesOf(combat, unit)
    local out = {}
    for _, u in ipairs(combat.units or {}) do
        if u.alive and u.side ~= unit.side and not Combat().isOffTile(u) then out[#out + 1] = u end
    end
    return out
end

-- ------------------------------------------------------------------------------------------- the Evil Eye

-- How long the soured blessing stays Rattled: a fight's length, the Lion's roar's 8 (status_rattled is the
-- injury's own status, which stands for 9999 ticks unless it is handed one).
Envy.SOUR_TICKS = 8

-- The blessing the eye sours on `body`: the first one Combat.dispellableOn would strip. Rattled is passed over
-- because the injury's status is not a debuff and so counts as a blessing there -- souring Rattled into Rattled
-- would be a turn that changed nothing.
local function blessingToSour(body)
    for _, id in ipairs(Combat().dispellableOn(body, math.huge)) do
        if id ~= "status_rattled" then return id end
    end
    return nil
end

-- The eye looks across at the Fairest. Returns the soured status id, or nil when it saw nobody, or saw a body
-- with nothing to sour.
function Envy.evilEye(combat, eye)
    if not (combat and eye and eye.alive) then return nil end
    local body = require("models.fairest").across(combat, eye)
    if not body then return nil end
    if not Combat().hasLineOfSight(combat, eye.x, eye.y, body.x, body.y) then return nil end
    local id = blessingToSour(body)
    if not id then return nil end
    local def = Status().defs[id]
    Status().remove(combat, body, id)
    Status().apply(combat, body, "status_rattled", { applier = eye, duration = Envy.SOUR_TICKS })
    Combat().logEvent(combat, "status", string.format("The Evil Eye falls on %s, and %s sours into Rattled.",
        nameOf(body), (def and def.name) or id), { eye, body })
    return id
end

-- ------------------------------------------------------------------------------------------------ Mirage

Envy.ILLUSIONS = 3

-- Is `unit` one of a Mirage's illusions? Read by Combat.dealFlatDamage (its blows land nothing) and
-- Status.isImmune (it weighs nothing, so the sand does not take it).
function Envy.illusory(unit)
    return unit ~= nil and unit.illusory == true
end

-- At the bell the real Mirage puts three copies of itself on the ground around it. Each is Summon.copy's double:
-- the same body, the same kit, `fragile` (any blow fells it, which is the review's "one health" without a bar
-- that gives it away), sustained by the real one, so killing it clears the board of them.
function Envy.raiseMirage(combat, real)
    if not (combat and real and real.alive) or real.illusory then return {} end
    local Summon = require("models.summon")
    local made = {}
    for _ = 1, Envy.ILLUSIONS do
        local x, y = Combat().openTileNear(combat, real.x, real.y)
        if not x then break end
        local copy = Summon.copy(combat, real, x, y, { fragile = true })
        if copy then
            copy.illusory = true
            -- Set after the copy arrived, so ground it was set down on may already have taken it: a weightless
            -- body is not Mired, whenever the sand reached it.
            if copy.alive and Status().has(copy, "status_mired") then Status().remove(combat, copy, "status_mired") end
            if copy.alive then made[#made + 1] = copy end
        end
    end
    return made
end

-- The real Mirage's illusions still standing.
function Envy.illusionsOf(combat, real)
    local out = {}
    for _, u in ipairs(combat.units or {}) do
        if u.alive and u.illusory and u.summoner == real then out[#out + 1] = u end
    end
    return out
end

-- Struck, the real one trades places with an illusion -- once a round (re-armed at the end of its own turn).
-- Returns the illusion it traded with, or nil.
function Envy.mirageShift(combat, real)
    if not (combat and real and real.alive) or real.illusory or real.mirageShifted then return nil end
    local list = Envy.illusionsOf(combat, real)
    if #list == 0 then return nil end
    local pick = list[Combat().roll(combat, #list)] or list[1]
    if not Combat().swapUnits(combat, real, pick) then return nil end
    real.mirageShifted = true
    -- Says that something moved, never which: the deception has to hold in the log too.
    Combat().logEvent(combat, "action", "The Mirage shimmers, and is somewhere else.", real)
    return pick
end

-- ---------------------------------------------------------------------------------------- the Patchwork

Envy.STITCH = "status_conjoined"
Envy.STITCH_TICKS = 20 -- Conjoined's own length; laid fresh each time the stitch moves

-- Stitch `foe` to the Patchwork: the Patchwork and that body share one link, so half of every wound the
-- Patchwork takes reaches them (Combat.echoWound). The stitch is pulled out of whoever held it before.
-- Returns true when `foe` holds the stitch afterwards.
function Envy.restitch(combat, patch, foe)
    if not (combat and patch and patch.alive and foe and foe.alive) then return false end
    if foe == patch or foe.side == patch.side then return false end
    local S = Status()
    patch.stitch = patch.stitch or {}
    local held = S.get(foe, Envy.STITCH)
    if patch.stitchedTo == foe and held and held.link == patch.stitch then return true end
    -- Out of the last body it held.
    local old = patch.stitchedTo
    if old and old ~= foe and old.alive then
        local s = S.get(old, Envy.STITCH)
        if s and s.link == patch.stitch then S.remove(combat, old, Envy.STITCH) end
    end
    patch.stitchedTo = nil
    -- The Patchwork's own end, which is what an echo travels out from. Conjoined is resistible and its returns
    -- diminish, which is right for a body somebody else binds and wrong for the one whose whole rule it is, so
    -- its own tally is cleared before each landing.
    local own = S.get(patch, Envy.STITCH)
    if not (own and own.link == patch.stitch) then
        if patch._afflicted then patch._afflicted[Envy.STITCH] = nil end
        own = S.apply(combat, patch, Envy.STITCH, { applier = patch, duration = Envy.STITCH_TICKS })
        if own then own.link = patch.stitch end
    end
    if not own then return false end
    own.remaining = math.max(own.remaining or 0, Envy.STITCH_TICKS)
    -- The new end. A strong mind still buys back some of the binding, as it does against the mage's.
    local st = S.apply(combat, foe, Envy.STITCH, { applier = patch, duration = Envy.STITCH_TICKS })
    if not st then return false end
    st.link = patch.stitch
    patch.stitchedTo = foe
    Combat().logEvent(combat, "status", string.format("The Patchwork's stitch moves to %s.", nameOf(foe)),
        { patch, foe })
    return true
end

-- ---------------------------------------------------------------------------------------------- Shade

-- Is a wall or ridge beside (x, y)? Anything orthogonally next to it that blocks a line of sight on its own --
-- a mountain ridge, a rock, a hill, a raised wall -- which is to say anything it can stand in the shadow of.
function Envy.besideCover(combat, x, y)
    local tiles = combat and combat.arena and combat.arena.tiles
    local Wall = require("models.wall")
    for _, d in ipairs({ { 0, -1 }, { 1, 0 }, { 0, 1 }, { -1, 0 } }) do
        local nx, ny = x + d[1], y + d[2]
        local row = tiles and tiles[ny]
        local cell = row and row[nx]
        local cost = ((cell and cell.sightCost) or 0) + Wall.sightCostAt(combat, nx, ny)
        if cell and cost >= Combat().SIGHT_BLOCK then return true end
        if Wall.blocksAt(combat, nx, ny) then return true end
    end
    return false
end

Envy.LIMN_TICKS = 10

-- Read where `unit` stands: beside cover it is Unseen (status_invisible), and with `limns` it is Limned on open
-- ground. Returns "unseen", "limned" or nil.
function Envy.reshadow(combat, unit, limns)
    if not (combat and unit and unit.alive) then return nil end
    local S = Status()
    if Envy.besideCover(combat, unit.x, unit.y) then
        if S.has(unit, "status_limned") then S.remove(combat, unit, "status_limned") end
        if not S.has(unit, "status_invisible") then S.apply(combat, unit, "status_invisible", { applier = unit }) end
        return S.has(unit, "status_invisible") and "unseen" or nil
    end
    if S.has(unit, "status_invisible") then S.remove(combat, unit, "status_invisible") end
    if limns then
        S.apply(combat, unit, "status_limned", { applier = unit, duration = Envy.LIMN_TICKS })
        return "limned"
    end
    return nil
end

-- ------------------------------------------------------------------------------------------ the Weighers

-- The two of `weigher`'s foes it sets on the scale: the two nearest it, the nearer first.
local function onTheScale(combat, weigher)
    local foes = foesOf(combat, weigher)
    table.sort(foes, function(a, b)
        local da, db = Combat().unitGap(weigher, a), Combat().unitGap(weigher, b)
        if da ~= db then return da < db end
        return (a.index or 0) < (b.index or 0)
    end)
    return foes[1], foes[2]
end

-- A Weigher weighs two of the company against each other. The heavier heart (more current health; a tie goes to
-- the nearer) is Weighed, and every Weigher strikes it; the lighter is Spared, and no Weigher does. The marks of
-- the last weighing come off first, so the scale names one pair at a time. Returns heavy, light.
function Envy.weigh(combat, weigher)
    if not (combat and weigher and weigher.alive) then return nil end
    local a, b = onTheScale(combat, weigher)
    if not (a and b) then return nil end
    local heavy, light = a, b
    if hp(b) > hp(a) then heavy, light = b, a end
    local S = Status()
    for _, u in ipairs(combat.units or {}) do
        if S.has(u, "status_weighed") then S.remove(combat, u, "status_weighed") end
        if S.has(u, "status_spared") then S.remove(combat, u, "status_spared") end
    end
    S.apply(combat, heavy, "status_weighed", { applier = weigher })
    S.apply(combat, light, "status_spared", { applier = weigher })
    Combat().logEvent(combat, "status", string.format("The Weighers set %s against %s: %s's heart is the heavier.",
        nameOf(heavy), nameOf(light), nameOf(heavy)), { weigher, heavy, light })
    return heavy, light
end

-- The body the scale names for the Weighers to strike, or nil.
function Envy.heavier(combat, weigher)
    for _, u in ipairs(combat.units or {}) do
        if u.alive and u.side ~= weigher.side and Status().has(u, "status_weighed") then return u end
    end
    return nil
end

-- ------------------------------------------------------------------------------- the Green-Eyed Monster

-- Every pair of `side` standing side by side (orthogonally adjacent), each pair once.
function Envy.pairsOf(combat, side)
    local list = {}
    for _, u in ipairs(combat.units or {}) do
        if u.alive and u.side == side and not Combat().isOffTile(u) then list[#list + 1] = u end
    end
    local out = {}
    for i = 1, #list do
        for j = i + 1, #list do
            if Combat().unitGap(list[i], list[j]) == 1 then out[#out + 1] = { list[i], list[j] } end
        end
    end
    return out
end

Envy.PAIR_DAMAGE = 2

-- The tile `body` is shoved to when driven `n` tiles straight away from `from`.
function Envy.awayFrom(body, from, n)
    local dx, dy = body.x - from.x, body.y - from.y
    if math.abs(dx) >= math.abs(dy) then dx, dy = (dx > 0 and 1 or (dx < 0 and -1 or 0)), 0
    else dx, dy = 0, (dy > 0 and 1 or -1) end
    if dx == 0 and dy == 0 then return nil end
    return { x = body.x + dx * n, y = body.y + dy * n }
end

-- The nearest other living body on `body`'s side, or nil.
function Envy.nearestAlly(combat, body)
    local best, bestD
    for _, u in ipairs(combat.units or {}) do
        if u ~= body and u.alive and u.side == body.side and not Combat().isOffTile(u) then
            local d = Combat().unitGap(body, u)
            if not bestD or d < bestD then best, bestD = u, d end
        end
    end
    return best
end

-- ------------------------------------------------------------------------------------------- the Nazar

-- The Evil Eye's charm, carried by the company (data/traits/trait_nazar.lua): the first debuff or curse that
-- would land on its bearer each fight is turned aside. One latch for both, kept on the unit, which is the fight.
-- `what` is "hex" (Combat.curseItem asks before a piece is taken) or a status's name (the trait asks once a
-- debuff has landed, and lifts it). Returns true when this one was turned aside.
function Envy.turnAside(combat, unit, what)
    if not (unit and unit.alive) or unit.nazarSpent then return false end
    if not require("models.trait").flag(unit, "turnsAside") then return false end
    unit.nazarSpent = true
    if combat then
        Combat().logEvent(combat, "status", string.format("%s's Nazar turns the %s aside.", nameOf(unit),
            what == "hex" and "hex" or (what or "affliction")), unit)
    end
    return true
end

-- ------------------------------------------------------------------------------------------- the planner

-- What one of these bodies does with its turn when its rule decides it, for AI.preempt; nil leaves the turn to
-- the ordinary planner. The company's own bodies are never compelled: an AI rule binds nobody the player drives.

-- Strike `tt` with `weapon` from here or from a tile `unit` can walk to; else walk as near it as the turn allows.
local function strikeOrClose(combat, unit, tt, weapon, reason)
    local C = Combat()
    local ab = weapon and weapon.activeAbility
    if not ab then return nil end
    for _, t in ipairs(C.abilityTargets(combat, unit, weapon)) do
        if t == tt then
            local cx, cy = C.nearestCell(unit.x, unit.y, tt)
            return { item = weapon, tx = cx, ty = cy, reason = reason }
        end
    end
    local minRange = C.abilityMinRange(ab)
    local best, dest
    for _, node in ipairs(C.reachableList(combat, unit)) do
        local range = C.abilityRange(combat, unit, ab, node.x, node.y) + C.adjacencyRangeBonus(unit.char, weapon)
        local d, cx, cy = C.reachFrom(unit, node.x, node.y, tt)
        if d <= range and d >= minRange
            and (not ab.requiresSight or C.sightFrom(combat, unit, node.x, node.y, cx, cy))
            and (not best or node.steps < best.steps) then
            best = { x = node.x, y = node.y, tx = cx, ty = cy, steps = node.steps }
        end
        local gap = C.cellGap(node.x, node.y, tt)
        if not dest or gap < dest.gap or (gap == dest.gap and node.steps < dest.steps) then
            dest = { x = node.x, y = node.y, gap = gap, steps = node.steps }
        end
    end
    if best then
        return { move = { x = best.x, y = best.y }, item = weapon, tx = best.tx, ty = best.ty, reason = reason }
    end
    if dest and dest.gap < C.unitGap(unit, tt) then return { move = { x = dest.x, y = dest.y }, reason = reason } end
    return nil
end

local function carried(unit, id)
    for _, item in ipairs(require("models.character").eachItem(unit.char)) do
        if item.id == id then return item end
    end
    return nil
end

local function ready(unit, item)
    return item ~= nil and Combat().itemBlockReason(unit, item) == nil
end

function Envy.plan(combat, unit)
    if not (combat and unit and unit.alive) or unit.side == "party" then return nil end
    local Trait = require("models.trait")
    -- THE WEIGHERS: every Weigher goes for the heavier heart, and never for the one the scale spared.
    if Trait.flag(unit, "weighsHearts") then
        local heavy = Envy.heavier(combat, unit)
        if heavy then
            local plan = strikeOrClose(combat, unit, heavy, Combat().defaultWeapon(unit.char), "the heavier heart")
            if plan then return plan end
            return { wait = true, reason = "the heavier heart is out of reach" }
        end
    end
    -- THE SAND-EELS: under the floor and up where the Fairest stands, when the dive is ready and in range.
    local surge = carried(unit, "weapon_eel_surge")
    if surge and ready(unit, surge) then
        local body = require("models.fairest").across(combat, unit)
        if body and Combat().cellGap(unit.x, unit.y, body) <= Combat().abilityRange(combat, unit, surge.activeAbility) then
            return { item = surge, tx = body.x, ty = body.y, reason = "under the Fairest" }
        end
    end
    -- THE GREEN-EYED MONSTER: it roars whenever the company stands close enough to be pulled apart.
    local roar = carried(unit, "ability_green_eyed_roar")
    if roar and ready(unit, roar) then
        local foe = foesOf(combat, unit)[1]
        if foe and #Envy.pairsOf(combat, foe.side) > 0 then
            return { item = roar, tx = unit.x, ty = unit.y, reason = "it hates closeness" }
        end
    end
    return nil
end

return Envy
