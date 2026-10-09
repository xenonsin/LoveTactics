-- THE GREY SHORE: the two rules the Crown's drowned dead carry, as one model so the gate, the stamp and the funnel
-- read the same three facts. Reviewed 2026-10-09 ("The Crown's Bestiary", slice E).
--
--   LETHE HAZE   any foe within 2 tiles of a bearer cannot use the same ability two turns running
--                (the Lethe-Drinker's organ, trait_lethe_haze; the Cup of Lethe, trait_cup_of_lethe)
--   NEVER FULL   any heal or draught that lands on a body within 2 tiles of a bearer is eaten: the bearer is
--                healed instead (the Hungry Ghost's organ, trait_never_full; the Pinhole Mouth, foes only,
--                trait_pinhole_mouth)
--
-- WHY THE HAZE IS A GATE IN Combat.itemBlockReason. That is the one function the greyed slot, the refused click,
-- the tooltip's red line and the AI's item filter all read, so a remembered ability greys itself, refuses the
-- press and drops out of the planner's list at once -- no caller learns what Lethe is. It reads the board
-- through `unit.combat` (Trait.attach's back-reference), the same seam Deaf Heart's presence uses, because the
-- gate is handed a unit and nothing else. Position is asked AT USE: step out of the haze and the ability you
-- used last turn is yours again, which is the review's second counter.
--
-- WHAT COUNTS AS "LAST TURN" is the unit's own previous turn: the ids it committed (Combat.useItem, at the
-- spend), rolled over at Combat.startTurn. A turn of only walking leaves the next one free. The fists
-- (`unarmed`) are never remembered, so a body whose one weapon is barred can always still throw a punch, and a
-- haze can never strand a body with nothing at all to do.
--
-- WHY NEVER FULL SITS BESIDE THE GALLOWS SEED in Combat.applyHeal. It is the same verb -- a heal drawn off the
-- patient whole onto somebody else -- asked by distance instead of by a planted seed, so it takes the seed's
-- place in the funnel (after the refusals and the inversion: a heal that was never going to land cannot be
-- eaten) and the seed's relay guard, so an eaten heal cannot be eaten again on its way to the ghost. The relay
-- lands as a DRINK (`feeding`), because a Hungry Ghost is undead and Grave-Cold would otherwise turn every heal
-- it ate into a wound -- the vampire's drink is the one heal a dead thing takes, and eating is drinking.

local Lethe = {}

Lethe.RADIUS = 2

local function Combat() return require("models.combat") end
local function Trait() return require("models.trait") end

local function name(u) return (u and u.char and u.char.name) or "It" end

-- ------------------------------------------------------------------------------------------- Lethe Haze

-- Is `item` one the haze remembers? Everything with an ability, except the bare fists.
local function remembered(item)
    if not (item and item.activeAbility and item.id) then return false end
    for _, t in ipairs(item.tags or {}) do
        if t == "unarmed" then return false end
    end
    return true
end

-- A unit's own turn opened (Combat.startTurn): what it used last time becomes what it used LAST turn.
function Lethe.turnOpened(unit)
    if not unit then return end
    unit.letheLast = unit.letheThis
    unit.letheThis = nil
end

-- A unit committed `item` (Combat.useItem, at the spend).
function Lethe.used(unit, item)
    if not (unit and remembered(item)) then return end
    unit.letheThis = unit.letheThis or {}
    unit.letheThis[item.id] = true
end

-- The hazing body standing within reach of `unit`, or nil: a living foe of it carrying `letheHaze`.
function Lethe.hazedBy(unit)
    local combat = unit and unit.combat
    if not (combat and combat.units) then return nil end
    for _, bearer in ipairs(combat.units) do
        if bearer ~= unit and bearer.alive and bearer.side ~= unit.side and bearer.traits then
            local t = Trait().flag(bearer, "letheHaze")
            if t and Combat().unitGap(bearer, unit) <= (t.def.radius or Lethe.RADIUS) then return bearer, t end
        end
    end
    return nil
end

-- The block Combat.itemBlockReason returns for `item`, or nil: it was used last turn and a haze holds `unit`.
function Lethe.barred(unit, item)
    if not (unit and unit.letheLast and item and unit.letheLast[item.id]) then return nil end
    if not remembered(item) then return nil end
    local bearer, t = Lethe.hazedBy(unit)
    if not bearer then return nil end
    return { kind = "lethe", reason = "lethe haze",
        text = (t.def.name or "Lethe Haze") .. " -- used last turn, so it is forgotten this one" }
end

-- ------------------------------------------------------------------------------------------- Never Full

-- The body that eats a heal aimed at `target`, or nil: the nearest living bearer of `eatsHeals` within its
-- radius (ties keep board order). A bearer never eats its own heal, and a `foesOnly` bearer (the Pinhole Mouth)
-- eats only a foe's.
function Lethe.healEater(combat, target)
    if not (combat and combat.units and target and target.alive) then return nil end
    local best, bestD
    for _, bearer in ipairs(combat.units) do
        if bearer ~= target and bearer.alive and not bearer.incapacitated and bearer.traits then
            local t = Trait().flag(bearer, "eatsHeals")
            if t and not (t.def.foesOnly and bearer.side == target.side) then
                local d = Combat().unitGap(bearer, target)
                if d <= (t.def.radius or Lethe.RADIUS) and (not bestD or d < bestD) then best, bestD = bearer, d end
            end
        end
    end
    return best
end

-- Combat.applyHeal's step: eat the heal if something near `target` is hungry. True when it was eaten (the
-- patient gets nothing). Runs under the funnel's relay guard, so the meal itself is never eaten in turn.
function Lethe.tryEat(combat, target, amount)
    if (amount or 0) <= 0 or combat._seedRelay then return false end
    local eater = Lethe.healEater(combat, target)
    if not eater then return false end
    local C = Combat()
    C.logEvent(combat, "status",
        string.format("%s eats the healing meant for %s.", name(eater), name(target)), { eater, target })
    combat._seedRelay = true
    local ok, err = pcall(C.applyHeal, combat, eater, amount, { feeding = true })
    combat._seedRelay = nil
    if not ok then error(err, 0) end
    return true
end

return Lethe
