-- THE UNBROKEN STREAK: the orc Berserker's drops (2026-09-26, "The Orcs of Wrath"). The Unbroken Axe counts its
-- own hits (data/traits/trait_unbroken.lua), Warpaint counts every hit (data/traits/trait_warpaint.lua). Each
-- keeps its own count of turns in a row, and the Unbroken badge carries the LONGER of the two -- so a body wearing
-- both is not +20, which is what round 2 approved.
local Status = require("models.status")

local Streak = {}

Streak.CAP = 5

-- A blow landed this turn, counted by the source that saw it ("axe" or "paint").
function Streak.hit(unit, source)
    unit._streakHit = unit._streakHit or {}
    unit._streakHit[source] = true
end

-- The bearer's turn is over: extend or break this source's count, then set the badge to the longer count.
function Streak.settle(combat, unit, source)
    if not (unit and unit.alive) then return end
    unit._streak = unit._streak or {}
    local hit = unit._streakHit and unit._streakHit[source]
    if unit._streakHit then unit._streakHit[source] = nil end
    unit._streak[source] = hit and math.min((unit._streak[source] or 0) + 1, Streak.CAP) or 0
    local best = 0
    for _, n in pairs(unit._streak) do best = math.max(best, n) end
    local s = Status.get(unit, "status_unbroken")
    if best <= 0 then
        if s then Status.remove(combat, unit, "status_unbroken") end
    elseif s then
        s.magnitude = best
    else
        Status.apply(combat, unit, "status_unbroken", { magnitude = best })
    end
end

return Streak
