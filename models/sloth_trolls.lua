-- SLOTH'S TROLLS AND ITS OGRE (slice B of "Sloth's Bestiary", reviewed 2026-10-03..04): the two rules of the
-- meltwater bridges that are about the board rather than about one body, kept in one place so the bodies, their
-- drops and the engine's two seams all ask the same functions.
--
--   THE TOLL        a foe that USES something within a keeper's reach is struck first, before the use resolves
--                   (Combat.useItem asks Trolls.collect). Walking and waiting are not uses, so they cost nothing.
--                   The Toll-Troll's toll reaches as far as its maul and is free; Bridge Tax, the player's copy,
--                   reaches 2 tiles, answers abilities only, and is billed like any other answer.
--   THE THROW       the Ogre lifts the nearest body beside it, either side, and throws it at the company's body
--                   farthest from it, up to 4 tiles: both take the impact and the thrown body lands beside its
--                   target. With nobody beside it, a slab of ice goes instead, for half (Trolls.ogrePlan, and the
--                   Ogre's Heave drop through Trolls.hurl).
--
-- A THROW IS A FORCED MOVE WITH A LANDING, the way a shove is: a body that cannot be moved (Root, Unmoved, Stout)
-- is not lifted, the landing is a real arrival (Combat.teleportUnit: the tile springs, a channel breaks), and the
-- impact is the collision's own unanswered blow -- nobody parries a thrown friend.

local Trolls = {}

-- How far the Ogre throws, and how far Bridge Tax reaches. The review's numbers.
Trolls.THROW_REACH = 4

local function Combat() return require("models.combat") end
local function Status() return require("models.status") end
local function Trait() return require("models.trait") end

local function name(u) return (u and u.char and u.char.name) or "Unit" end

-- ---------------------------------------------------------------------------
-- THE TOLL
-- ---------------------------------------------------------------------------

-- The weapon `keeper` collects with against a user standing `dist` away, or nil when its toll does not reach.
-- A reach toll (no `radius`) collects with whatever in hand reaches back; a radius toll swings what it has.
local function tollWeapon(combat, keeper, rule, dist)
    local C = Combat()
    if rule.radius then
        if dist > rule.radius then return nil end
        return C.answeringWeapon(combat, keeper, dist) or C.defaultWeapon(keeper.char)
    end
    return C.answeringWeapon(combat, keeper, dist)
end

-- What a priced toll costs: the swing's own price, doubled for each answer already thrown since the keeper last
-- acted -- Trait.answerCost's law, restated here because a radius toll may swing a weapon that does not reach.
local function tollCost(keeper, weapon)
    local costs = require("models.item").costList(weapon and weapon.activeAbility and weapon.activeAbility.cost)
    local mult = math.min(2 ^ (keeper.answersThisRound or 0), Trait().ANSWER_ESCALATION_CAP)
    for _, c in ipairs(costs) do c.amount = math.floor(c.amount * mult) end
    return costs
end

-- Every keeper standing over `unit` as it uses `item`, struck in board order. Returns true when at least one toll
-- was collected. Called from Combat.useItem after the use is validated and before anything is spent, so a body
-- the toll fells has paid nothing else and its action never arrives.
function Trolls.collect(combat, unit, item)
    if not (combat and unit and unit.alive and item) then return false end
    local T, S, C = Trait(), Status(), Combat()
    -- An answer is not a use: a parry thrown inside somebody's turn must not set off a toll of its own.
    if T.isReacting(unit) then return false end
    local collected = false
    for _, keeper in ipairs(combat.units or {}) do
        if not unit.alive then break end
        if keeper ~= unit and keeper.alive and keeper.side ~= unit.side and not C.isOffTile(keeper) then
            local t = T.flag(keeper, "toll")
            local rule = t and t.def.toll
            if rule and not S.disablesReactions(keeper)
                and (not rule.abilitiesOnly or item.type == "ability") then
                local dist = C.unitGap(keeper, unit)
                local weapon = tollWeapon(combat, keeper, rule, dist)
                local pay = weapon and rule.priced and tollCost(keeper, weapon) or nil
                local affordable = true
                for _, c in ipairs(pay or {}) do
                    if C.resource(keeper.char, c.stat) < c.amount then affordable = false end
                end
                if weapon and affordable then
                    for _, c in ipairs(pay or {}) do C.drainResource(keeper.char, c.stat, c.amount) end
                    if pay then keeper.answersThisRound = (keeper.answersThisRound or 0) + 1 end
                    C.logEvent(combat, "action", string.format("%s takes its toll from %s first.",
                        name(keeper), name(unit)), { keeper, unit })
                    -- Flagged a reaction for the blow's whole flight, as Keen Senses' preempt is, so the user's
                    -- own parry reads it as an answer and does not answer back.
                    keeper._reacting = keeper._reacting or {}
                    local was = keeper._reacting.toll
                    keeper._reacting.toll = true
                    C.dealDamage(combat, keeper, unit, weapon)
                    keeper._reacting.toll = was
                    collected = true
                end
            end
        end
    end
    return collected
end

-- ---------------------------------------------------------------------------
-- THE THROW
-- ---------------------------------------------------------------------------

local function liftable(u)
    return u and u.alive and not Combat().isOffTile(u) and (u.w or 1) == 1 and (u.h or 1) == 1
end

-- The body beside `thrower` it would lift: the first, in board order, standing orthogonally beside it, either side,
-- that can be moved at all.
function Trolls.besideBody(combat, thrower)
    local C, S = Combat(), Status()
    for _, u in ipairs(combat.units or {}) do
        if u ~= thrower and liftable(u) and C.unitGap(thrower, u) == 1 and not S.blocksForcedMove(u) then
            return u
        end
    end
    return nil
end

-- The foe of `thrower` a throw from `from` goes at: the one farthest from the thrower among those within
-- THROW_REACH of `from`, never `exclude`. Ties keep board order.
function Trolls.mark(combat, thrower, from, exclude)
    local C = Combat()
    local best, bestGap
    for _, u in ipairs(combat.units or {}) do
        if u ~= exclude and u ~= thrower and u.alive and u.side ~= thrower.side and not C.isOffTile(u)
            and C.unitGap(from, u) <= Trolls.THROW_REACH then
            local gap = C.unitGap(thrower, u)
            if not bestGap or gap > bestGap then best, bestGap = u, gap end
        end
    end
    return best
end

-- Where a thrown body comes down beside `target`: the open tile orthogonally beside its footprint nearest the
-- tile the body left, ties in a fixed order. `body`'s own tile counts as open, since it is leaving it.
local function landing(combat, body, target)
    local C = Combat()
    local best, bx, by
    for _, cell in ipairs(C.unitCells(target)) do
        for _, d in ipairs({ { 0, -1 }, { 1, 0 }, { 0, 1 }, { -1, 0 } }) do
            local x, y = cell.x + d[1], cell.y + d[2]
            if C.cellGap(x, y, target) == 1 and C.footprintFree(combat, 1, 1, x, y, body) then
                local dd = math.abs(x - body.x) + math.abs(y - body.y)
                if not best or dd < best then best, bx, by = dd, x, y end
            end
        end
    end
    return bx, by
end

-- `thrower` throws `body` at `target`: the body lands beside the target, then both take `amount` of impact. A body
-- nothing can move is not lifted (it holds its ground, and nobody is hurt). Returns true when the throw happened.
function Trolls.hurl(combat, thrower, body, target, amount)
    local C, S = Combat(), Status()
    if not (liftable(body) and target and target.alive) then return false end
    if S.blocksForcedMove(body) then
        C.logEvent(combat, "status", string.format("%s holds its ground.", name(body)), body)
        return false
    end
    C.logEvent(combat, "action", string.format("%s throws %s at %s.", name(thrower), name(body), name(target)),
        { thrower, body, target })
    local lx, ly = landing(combat, body, target)
    if lx then C.teleportUnit(combat, body, lx, ly, { glide = true, silent = true }) end
    -- The impact is its own beat, as a shove's collision is, and it is answered by nothing: no attacker.
    C.beginBeat(combat)
    if body.alive then C.dealFlatDamage(combat, body, amount, { "physical", "impact" }, "the throw") end
    if target.alive then C.dealFlatDamage(combat, target, amount, { "physical", "impact" }, "the throw") end
    C.endBeat(combat)
    return true
end

-- The slab: thrown at `target` for half of `amount`.
function Trolls.slab(combat, thrower, target, amount)
    local C = Combat()
    if not (target and target.alive) then return false end
    C.logEvent(combat, "action", string.format("%s tears up a slab of ice and throws it at %s.",
        name(thrower), name(target)), { thrower, target })
    C.dealFlatDamage(combat, target, math.max(1, math.floor(amount / 2)), { "physical", "impact", "ice" }, "the slab")
    return true
end

-- CAN'T BE BOTHERED, resolved (ability_cant_be_bothered): aimed at a body beside the Ogre, it is lifted and
-- thrown; aimed anywhere else, the slab goes at whoever stands there.
function Trolls.ogreThrow(combat, ogre, tx, ty, amount)
    local C = Combat()
    local aimed = C.unitAt(combat, tx, ty)
    if aimed and aimed ~= ogre and C.unitGap(ogre, aimed) == 1 then
        local target = Trolls.mark(combat, ogre, aimed, aimed)
        if target then return Trolls.hurl(combat, ogre, aimed, target, amount) end
        return false
    end
    if aimed and aimed.side ~= ogre.side then return Trolls.slab(combat, ogre, aimed, amount) end
    return false
end

-- The Ogre's turn, for AI.preempt: lift whoever is beside it and throw them at the farthest of the company in
-- reach; with nobody beside it (or nobody to throw them at), the slab. Nil leaves the turn to the planner, which
-- has nowhere to walk it.
Trolls.OGRE_THROW = "ability_cant_be_bothered"

function Trolls.ogrePlan(combat, unit)
    if unit.side == "party" then return nil end
    local C = Combat()
    local item
    for _, it in ipairs(require("models.character").eachItem(unit.char)) do
        if it.id == Trolls.OGRE_THROW then item = it end
    end
    if not item or C.itemBlockReason(unit, item) then return nil end
    local body = Trolls.besideBody(combat, unit)
    if body and Trolls.mark(combat, unit, body, body) then
        return { item = item, tx = body.x, ty = body.y, reason = "can't be bothered" }
    end
    local target = Trolls.mark(combat, unit, unit, nil)
    if target then
        local x, y = C.nearestCell(unit.x, unit.y, target)
        return { item = item, tx = x, ty = y, reason = "the slab" }
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- SCARRING BLOWS
-- ---------------------------------------------------------------------------

-- The wound a scarring club opens lasts until its striker's next turn: lifted there from every body it opened it on.
-- (It is the Unclosing Wound -- one word for "cannot be healed" -- laid long and taken off on the striker's turn.)
function Trolls.closeScars(combat, striker)
    local S = Status()
    for _, u in ipairs(combat.units or {}) do
        local s = S.get(u, "status_unclosing_wound")
        if s and s.opener == striker then S.remove(combat, u, "status_unclosing_wound") end
    end
end

return Trolls
