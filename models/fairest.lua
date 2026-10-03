-- THE FAIREST: Envy's word for whoever on a side holds the most blessings (reviewed 2026-10-01..03, "Envy's
-- Bestiary"). The Evil Eye sours the Fairest's blessings, Leviathan rises under the Fairest, and its brood the
-- Sand-Eels bite it; one helper so every reader agrees on who that is.
--
-- A BLESSING is what Combat.dispellableOn would strip: any status that is not a debuff (the Glass-Eater's
-- definition, which is the circle's own). TIES GO TO THE MOST CURRENT HEALTH, so there is always a Fairest
-- while anyone stands -- a company that holds no blessings at all is ranked by health alone, which is what
-- "nothing towers" leaves to compare.
--
-- Pure logic (no love.graphics), so it loads under the headless tests.

local Fairest = {}

function Fairest.blessings(unit)
    local Combat = require("models.combat")
    return #Combat.dispellableOn(unit, math.huge)
end

local function hp(u)
    local h = u.char and u.char.stats and u.char.stats.health
    return (type(h) == "table" and h.current) or 0
end

-- The Fairest of `side`, skipping anyone in `except` (a set keyed by unit). Nil when nobody on that side stands.
function Fairest.of(combat, side, except)
    local best, bestN, bestHp
    for _, u in ipairs(combat.units or {}) do
        if u.alive and u.side == side and not (except and except[u]) then
            local n, h = Fairest.blessings(u), hp(u)
            if not bestN or n > bestN or (n == bestN and h > bestHp) then best, bestN, bestHp = u, n, h end
        end
    end
    return best
end

-- The Fairest among `unit`'s foes: the side it looks across at.
function Fairest.across(combat, unit, except)
    local enemySide = nil
    for _, u in ipairs(combat.units or {}) do
        if u.alive and u.side ~= unit.side then enemySide = u.side break end
    end
    return enemySide and Fairest.of(combat, enemySide, except) or nil
end

return Fairest
