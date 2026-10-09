-- SPIRIT BODY: the Archons' race rule (data/races/archon.lua), as one model so the trait that throws a wisp, the
-- walk that brings it home and the arrival that raises the body all read the same three facts. Reviewed
-- 2026-10-09 ("The Crown's Bestiary", round 2), from the author's own note: "the wisp and the body is separated,
-- and the wisp goes back to the body so you have to stop it".
--
-- THE SHAPE:
--   * An Archon falls (trait_spirit_body's onDeath). Its body lies where it fell, INCAPACITATED in the ordinary
--     downed window, and a wisp (character_archon_wisp) is thrown three tiles clear -- away from whoever struck
--     the blow, so the company has to turn round to chase it.
--   * The wisp walks home (models/ai.lua's `gather` walk, steered by the `seeksBody` flag).
--   * Ending one of its own turns beside its goal, it ARRIVES: the body is raised at half health through
--     Combat.reanimate, and the wisp is spent.
--
-- WHY IT LEANS ON THE REVIVE GATE INSTEAD OF WRITING ITS OWN. Combat.reanimate already refuses a body whose
-- window has closed (it went cold) and a tile a living unit stands on. Those are exactly two of the author's
-- three counters -- run the clock out, or stand on the body -- so the rule inherits them for free, and the third
-- (kill the wisp) is just a body on the board.
--
-- WHY THE WISP IS NOT THE BODY'S SUMMON. Combat's killUnit dismisses every summon of a body the moment it
-- falls, AFTER the death hooks run -- so a wisp summoned with its body as its sustainer would be gone before it
-- took a step. It is spawned with `summoner = false` and pointed home through `wispOf` instead. A living wisp is
-- a living enemy, so a kill-all fight does not end while one is still walking: "would rather just remain in the
-- fight".
--
-- TWO SEAMS FOR THE BODIES THAT BEND THE WALK (built in their own slices, not here):
--   * `wisp.wispGoal` -- a unit that is not the wisp's body, which the wisp walks to instead (the Archon Duke's
--     Ascension takes a wisp that comes near it; the Hollow Crown's throne draws its court's wisps in phase 1).
--   * Arriving at such a goal fires `onWispTaken` on the goal's traits (Trait.fire) with { wisp, body }, and the
--     body stays down. The goal decides what taking a wisp means.

local Spirit = {}

Spirit.ORGAN = "utility_archon_spirit"
Spirit.WISP = "character_archon_wisp"
Spirit.THROW = 3     -- how far clear of the body the wisp lands (Chebyshev ring)
Spirit.RAISE_AT = 0.5 -- the share of its health a raised body stands at

local function sign(n) if n > 0 then return 1 elseif n < 0 then return -1 end return 0 end

-- Where the wisp lands: an open tile on the ring THROW tiles out from the body, the one farthest from whoever
-- struck it down (ties keep scan order, so a seed replays the same throw). With no attacker the ring's first
-- open tile; with the ring full, the nearest open tile within it.
function Spirit.landing(combat, body)
    local Combat = require("models.combat")
    local foe = body.lastAttacker
    local best, bestD
    local r = Spirit.THROW
    for dy = -r, r do
        for dx = -r, r do
            if math.max(math.abs(dx), math.abs(dy)) == r then
                local x, y = body.x + dx, body.y + dy
                if Combat.footprintFree(combat, 1, 1, x, y) then
                    local d = foe and (math.abs(x - foe.x) + math.abs(y - foe.y)) or 0
                    if not bestD or d > bestD then best, bestD = { x = x, y = y }, d end
                end
            end
        end
    end
    if best then return best.x, best.y end
    -- A crowded board: toward the attacker's far side, then anywhere near.
    local ax, ay = 0, 0
    if foe then ax, ay = sign(body.x - foe.x), sign(body.y - foe.y) end
    return Combat.openBlockNear(combat, body.x + ax, body.y + ay, 1, 1, { radius = r })
end

-- Throw the wisp. Refuses a summon (a wisp is an Archon too, and its death must be final), a decoy, a body that
-- has already thrown its one wisp, and a body that left no remains to come back to (it sank, or was devoured).
-- Returns the wisp, or nil.
function Spirit.release(combat, body)
    if not (combat and body and body.char) then return nil end
    if body.summoned or body.decoyOf or body.spiritSpent then return nil end
    if body.sank or body.devoured or not body.incapacitated then return nil end
    body.spiritSpent = true
    local x, y = Spirit.landing(combat, body)
    if not x then return nil end
    local Summon = require("models.summon")
    local wisp = Summon.spawn(combat, body, Spirit.WISP, x, y, { summoner = false, announce = false })
    if not wisp then return nil end
    wisp.wispOf = body
    require("models.combat").logEvent(combat, "system",
        string.format("%s's spirit tears loose.", body.char.name or "The Archon"), { body, wisp })
    return wisp
end

-- Where a wisp is walking: its override goal while that goal stands, else its own body. Nil when it has nowhere
-- left to go (no body, or the body went cold).
function Spirit.goal(combat, wisp)
    local g = wisp and wisp.wispGoal
    if g and g.alive then return g end
    local body = wisp and wisp.wispOf
    if body and body.incapacitated then return body end
    return nil
end

-- End of the wisp's own turn: beside its goal, it arrives. Its body: raised at half (refused on an occupied or
-- cold body, and then the wisp waits, or fades if the body has gone cold). Another goal: that goal takes it
-- (`onWispTaken`), the body stays down, and the wisp is spent. Returns true when the wisp was spent.
function Spirit.tryArrive(combat, wisp)
    local Combat = require("models.combat")
    if not (combat and wisp and wisp.alive) then return false end
    local body = wisp.wispOf
    local goal = Spirit.goal(combat, wisp)
    if not goal then
        Combat.dismiss(combat, wisp, "The wisp fades: there is nothing left to go back to.")
        return true
    end
    if Combat.unitGap(wisp, goal) > 1 then return false end
    if goal ~= body then
        require("models.trait").fire(combat, goal, "onWispTaken", { wisp = wisp, body = body })
        Combat.dismiss(combat, wisp, string.format("%s takes the wisp.", goal.char and goal.char.name or "It"))
        return true
    end
    if Combat.reanimate(combat, body, Spirit.RAISE_AT) then
        Combat.dismiss(combat, wisp, "The wisp goes back in.")
        return true
    end
    return false
end

return Spirit
