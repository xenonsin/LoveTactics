-- THE KINSLAYER: Envy's seat-floor elite (reviewed 2026-10-01..03, "Envy's Bestiary", row kn_body, approved and
-- named "the Kinslayer"). The first envy and the first murder, renamed off the page's biblical name ("too direct
-- to the bible") and moved off the stair to an elite. Nothing here names him anything else.
--
--   THE FAVOURED ONE  he hunts the body of the company healed or blessed most this fight. Favour is a COUNT, one
--                     for every heal that put health back and one for every blessing that landed fresh -- a
--                     blessing is what Combat.dispellableOn would strip, the Fairest's definition, so an
--                     undispellable badge is never one. The count is shown on the favoured body as a badge
--                     (status_favoured), restamped at the end of every turn; ties go to the most current
--                     health, as the Fairest's do.
--   THE MARK          whoever lands his killing blow takes 7 times his last hit (data/traits/trait_the_mark.lua).
--                     A killer is the attacker of the blow that felled him, stamped on the body by
--                     Combat.dealFlatDamage -- so a burn, a hazard or a trap fells him with no killer at all, and
--                     a thrown bomb (a consumable) is no killer either. A summon that lands it takes the Mark
--                     itself, which is the counter the review named.
--
-- THE COUNTERPLAY, STATED: spread your healing, and finish him with a summon, a bomb, a hazard or a burn.
--
-- Pure logic, headless-safe; Combat is reached lazily.

local Status = require("models.status")

local Kinslayer = {}

Kinslayer.BADGE = "status_favoured"
Kinslayer.HEALED = "healedTaken" -- the Combat.tally a heal banks on the body it landed on (Combat.applyHeal)

local function C() return require("models.combat") end
local function T() return require("models.trait") end

local function hp(u)
    local h = u.char and u.char.stats and u.char.stats.health
    return (type(h) == "table" and h.current) or 0
end

-- The favour ledger is the hunter's own: two Kinslayers on one board each keep count.
local function ledger(hunter)
    hunter.favour = hunter.favour or {}
    return hunter.favour
end

-- A blessing landed fresh on somebody: count it if it is a blessing on one of the hunter's foes.
function Kinslayer.noteBlessing(hunter, recipient, status)
    if not (hunter and recipient and status and recipient.side ~= hunter.side) then return end
    local def = status.def or Status.defs[status.id]
    if not def or def.debuff or def.undispellable or def.hideLog then return end
    local book = ledger(hunter)
    book[recipient] = (book[recipient] or 0) + 1
end

-- How favoured `u` is in `hunter`'s eyes: its blessings counted, plus every heal it has taken this fight.
function Kinslayer.favourOf(hunter, u)
    return (ledger(hunter)[u] or 0) + C().tallyCount(u, Kinslayer.HEALED)
end

-- The favoured one among `hunter`'s foes, or nil while nobody has been healed or blessed at all.
function Kinslayer.favoured(combat, hunter)
    local best, bestN, bestHp
    for _, u in ipairs(combat.units or {}) do
        if u.alive and u.side ~= hunter.side and not u.summoned and not C().isOffTile(u) then
            local n = Kinslayer.favourOf(hunter, u)
            if n > 0 and (not bestN or n > bestN or (n == bestN and hp(u) > bestHp)) then
                best, bestN, bestHp = u, n, hp(u)
            end
        end
    end
    return best, bestN
end

-- Put the counter on whoever is favoured now, and take it off whoever was.
function Kinslayer.restamp(combat, hunter)
    local who, n = Kinslayer.favoured(combat, hunter)
    local was = hunter.favouredOne
    if was and was ~= who and Status.has(was, Kinslayer.BADGE) then Status.remove(combat, was, Kinslayer.BADGE) end
    hunter.favouredOne = who
    if who then Status.apply(combat, who, Kinslayer.BADGE, { magnitude = n }) end
    return who
end

-- Strike `tt` with the default weapon, walking first if it must; nil when it cannot be reached this turn.
local function strikeAt(combat, unit, tt, reason)
    local Combat = C()
    local weapon = Combat.defaultWeapon(unit.char)
    local ab = weapon and weapon.activeAbility
    if not ab then return nil end
    local minRange = Combat.abilityMinRange(ab)
    local nodes = { { x = unit.x, y = unit.y, steps = 0 } }
    for _, node in ipairs(Combat.reachableList(combat, unit)) do nodes[#nodes + 1] = node end
    local best
    for _, node in ipairs(nodes) do
        local range = Combat.abilityRange(combat, unit, ab, node.x, node.y) + Combat.adjacencyRangeBonus(unit.char, weapon)
        local d, cx, cy = Combat.reachFrom(unit, node.x, node.y, tt)
        if d <= range and d >= minRange and (not best or node.steps < best.steps) then
            best = { x = node.x, y = node.y, tx = cx, ty = cy, steps = node.steps }
        end
    end
    if not best then return nil end
    local plan = { item = weapon, tx = best.tx, ty = best.ty, reason = reason }
    if best.x ~= unit.x or best.y ~= unit.y then plan.move = { x = best.x, y = best.y } end
    return plan
end

-- AI.preempt: he goes for the favoured one -- strikes it if he can reach it this turn, closes on it if he
-- cannot. Nil (the ordinary planner) while nobody is favoured, or while he cannot move or swing at all.
function Kinslayer.plan(combat, unit)
    if not (unit and unit.alive and unit.traits) then return nil end
    if not T().flag(unit, "huntsFavoured") then return nil end
    local tt = Kinslayer.favoured(combat, unit)
    if not tt then return nil end
    if Status.halted(unit) then return nil end
    local plan = strikeAt(combat, unit, tt, "hunting the favoured one")
    if plan then return plan end
    if Status.stopsMovement(unit) or Status.blocksMove(unit) then return nil end
    local Combat = C()
    local dest
    for _, node in ipairs(Combat.reachableList(combat, unit)) do
        local d = Combat.cellGap(node.x, node.y, tt)
        if not dest or d < dest.dist then dest = { x = node.x, y = node.y, dist = d } end
    end
    if dest and dest.dist < Combat.cellGap(unit.x, unit.y, tt) then
        return { move = { x = dest.x, y = dest.y }, reason = "closing on the favoured one" }
    end
    return nil
end

-- THE MARK: the bearer has fallen. Whoever landed the felling blow takes `times` x the measured blow, unmitigated
-- -- `measure` "lastHit" is the bearer's own last landed hit (the Kinslayer's), "killingBlow" the blow that felled
-- it (The Mark, the duelist's drop). Returns the damage dealt, or 0 when the Mark finds no killer.
function Kinslayer.killerOf(fallen)
    local killer = fallen and fallen.lastBlowBy
    if not (killer and killer.alive and killer ~= fallen and killer.side ~= fallen.side) then return nil end
    local item = fallen.lastBlowItem
    if item and item.type == "consumable" then return nil end -- a thrown bomb: nobody's hand
    return killer
end

function Kinslayer.mark(combat, fallen, times, measure)
    local killer = Kinslayer.killerOf(fallen)
    if not killer then return 0 end
    local blow = (measure == "killingBlow") and fallen.lastBlowTaken or fallen.lastHitDealt
    blow = math.floor(blow or 0)
    if blow <= 0 then return 0 end
    local Combat = C()
    Combat.logEvent(combat, "status", string.format("The Mark falls on %s.",
        (killer.char and killer.char.name) or "the killer"), { fallen, killer })
    return Combat.dealFlatDamage(combat, killer, blow * (times or 7), { "dark" }, "the Mark", nil, { raw = true })
end

return Kinslayer
