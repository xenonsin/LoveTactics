-- THE STOOP: a flier coming down on one body and, when that body is standing alone, carrying it off and
-- dropping it somewhere its company is not. Shared by four items, which is why it is a model and not a
-- block copied four times:
--   ability_take_wing   the wyvern's -- a wind-up, and this is what its channel resolves into
--   ability_stoop       the Highwing's -- the same dive, cast straight out of its High Wind
--   ability_skyward     the company's trophy -- the landing half only, no carry
--   ability_bear_away   the company's trophy -- the carry half only, ally or foe, no dive
--
-- THE THREE RULES, as reviewed (2026-09-23, "The Wyverns", round 2):
--   ALONE      no living ally on the four tiles directly beside the body (not the diagonals -- the review
--              asked for "directly adjacent"). A body with a friend at its shoulder is not lifted, and the
--              dive does it no harm at all: the review put every point of the Stoop's damage on the DROP.
--   LIFTABLE   a 1x1 body that is not anchored (Status.blocksForcedMove -- Root, and everything else that
--              says no shove moves it). The web that holds a company also holds it down.
--   THE DROP   the carried body lands on the tile furthest from its own side, web included (the review
--              denied sparing it), and takes the fall. At or under TWICE the dropper's Damage it does not
--              get up: a clean kill, like Coup de Grace's, and never on a boss.
--
-- Everything that moves a body goes through `fx` (fx.teleport / fx.teleportUser), so the hover preview
-- records the landing instead of making it, and everything that READS the board goes through fx.combat.
-- The grader's dry run has no board at all; there the dive is rated as the drop it ends in.
local Status = require("models.status")

-- Combat is reached LAZILY: item blueprints require this file, and the item registry is loaded while
-- models/combat.lua is itself still being required -- a top-level require here would hand back Lua's
-- in-progress sentinel instead of the module. No item file requires models.combat at load, for this.
local Combat = setmetatable({}, { __index = function(_, k) return require("models.combat")[k] end })

local Stoop = {}

-- How many times the dropper's own Damage a body can have left and still not survive the fall. A formula
-- rather than a flat line, so the deeper the wyvern the higher the ledge: 26 / 30 / 34 across the line.
Stoop.EXECUTE_MULT = 2

-- The four tiles directly beside a body -- ALONE is asked on these, never the diagonals.
local ORTHO = { { 0, -1 }, { 1, 0 }, { 0, 1 }, { -1, 0 } }
-- Every neighbour, orthogonals first, for where the dive may touch down beside its mark.
local RING = { { 0, -1 }, { 1, 0 }, { 0, 1 }, { -1, 0 }, { 1, -1 }, { 1, 1 }, { -1, 1 }, { -1, -1 } }

local function board(fx) return fx and fx.combat and fx.combat.arena and fx.combat or nil end

local function chebyshev(ax, ay, bx, by) return math.max(math.abs(ax - bx), math.abs(ay - by)) end

-- Is `body` standing with nobody from its own side directly beside it?
function Stoop.alone(combat, body)
    for _, d in ipairs(ORTHO) do
        local u = Combat.unitAt(combat, body.x + d[1], body.y + d[2])
        if u and u ~= body and u.alive and u.side == body.side then return false end
    end
    return true
end

-- Can `body` be picked up and carried at all?
function Stoop.liftable(body)
    if not (body and body.alive) then return false end
    if (body.w or 1) > 1 or (body.h or 1) > 1 then return false end
    return not Status.blocksForcedMove(body)
end

-- Set the diver down beside `body`: the open neighbour nearest where it is now, orthogonals first.
-- Returns true once it has landed (or was already beside it).
function Stoop.landBeside(fx, body)
    local combat, user = board(fx), fx.user
    if not combat then return false end
    if chebyshev(user.x, user.y, body.x, body.y) == 1 then return true end
    local bestX, bestY, bestD
    for _, d in ipairs(RING) do
        local x, y = body.x + d[1], body.y + d[2]
        if Combat.footprintFree(combat, 1, 1, x, y, user) then
            local dist = chebyshev(user.x, user.y, x, y)
            if not bestD or dist < bestD then bestX, bestY, bestD = x, y, dist end
        end
    end
    if not bestX then return false end
    fx.teleportUser(bestX, bestY, { glide = true })
    return true
end

-- Where a carry ends: a tile `w` for the carrier within `reach` of where it stands, and a tile `p` for
-- the carried body directly beside `w`, chosen so `p` is as far as the board allows from the nearest
-- body on the carried one's own side (or, with nobody left on that side, from where it was lifted).
-- `keepSide` flips the score for a RESCUE (Bear Away on an ally): nearest its own side instead.
-- Walked in a fixed order, so the same board always answers the same pair.
function Stoop.carryDest(combat, carrier, body, reach, keepSide)
    local friends = {}
    for _, u in ipairs(combat.units) do
        if u.alive and u ~= body and u ~= carrier and u.side == body.side then friends[#friends + 1] = u end
    end
    local function score(px, py)
        if #friends == 0 then return chebyshev(px, py, body.x, body.y) end
        local near
        for _, f in ipairs(friends) do
            local d = chebyshev(px, py, f.x, f.y)
            if not near or d < near then near = d end
        end
        return keepSide and -near or near
    end
    local best
    for dy = -reach, reach do
        for dx = -reach, reach do
            local wx, wy = carrier.x + dx, carrier.y + dy
            if not (wx == body.x and wy == body.y)
                and Combat.footprintFree(combat, 1, 1, wx, wy, carrier, body) then
                for _, d in ipairs(ORTHO) do
                    local px, py = wx + d[1], wy + d[2]
                    if not (px == carrier.x and py == carrier.y)
                        and Combat.footprintFree(combat, 1, 1, px, py, carrier, body) then
                        local s = score(px, py)
                        if not best or s > best.s then best = { s = s, w = { x = wx, y = wy }, p = { x = px, y = py } } end
                    end
                end
            end
        end
    end
    if not best then return nil end
    return best.w, best.p
end

-- Carry `body` off: both fly, and the body is set down beside the carrier. Returns true if it moved.
function Stoop.carry(fx, body, reach, keepSide)
    local combat = board(fx)
    if not (combat and Stoop.liftable(body)) then return false end
    local w, p = Stoop.carryDest(combat, fx.user, body, reach, keepSide)
    if not w then return false end
    fx.teleport(body, p.x, p.y, { glide = true })
    fx.teleportUser(w.x, w.y, { glide = true })
    return true
end

-- The fall. A body at or under EXECUTE_MULT x the dropper's Damage is killed outright (raw, its whole
-- health, as Coup de Grace strikes); anyone heavier takes the drop as an ordinary blow. Never a boss.
function Stoop.threshold(dropper)
    return Stoop.EXECUTE_MULT * Combat.flatStat(dropper, "damage")
end

function Stoop.drop(fx, body)
    if not (body and body.alive) then return 0 end
    local hp = body.char and body.char.stats and body.char.stats.health
    if hp and not body.char.boss and hp.current <= Stoop.threshold(fx.user) then
        return fx.damage(body, { amount = hp.max, raw = true })
    end
    return fx.damage(body)
end

-- COMING DOWN: land beside the body on the marked tile, or -- if it walked off the mark -- on the tile or
-- beside it, harming nobody. That is the dodge the channel's tell was painted for. Returns the body it
-- came down beside (alive, and on the far side from the diver), or nil.
function Stoop.comeDown(fx)
    local combat, body = board(fx), fx.target
    if not combat then return nil end
    if body and body.alive and body.side ~= fx.user.side then
        if Stoop.landBeside(fx, body) then return body end
        return nil
    end
    if fx.tx and fx.ty then
        if Combat.footprintFree(combat, 1, 1, fx.tx, fx.ty, fx.user) then
            fx.teleportUser(fx.tx, fx.ty, { glide = true })
        else
            local x, y = Combat.openTileNear(combat, fx.tx, fx.ty)
            if x then fx.teleportUser(x, y, { glide = true }) end
        end
    end
    return nil
end

-- THE WHOLE DIVE, as the wyvern and the Highwing cast it. `reach` is how far the carry flies.
-- Returns "carried", "landed" (beside a body that was not alone, or could not be lifted), or nil.
function Stoop.dive(fx, reach)
    if not board(fx) then
        -- The grader's board-less dry run: rate the dive as the drop it ends in.
        if fx.target then fx.damage(fx.target) end
        return nil
    end
    local body = Stoop.comeDown(fx)
    if not body then return nil end
    if not Stoop.alone(board(fx), body) then return "landed" end
    if not Stoop.carry(fx, body, reach) then return "landed" end
    Stoop.drop(fx, body)
    return "carried"
end

return Stoop
