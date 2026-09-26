-- The goblins' Blood Feud (data/traits/trait_blood_feud.lua, reviewed 2026-09-26, "The Goblins of Wrath").
--
-- ONE FEUD PER SIDE. Whoever last hit a goblin is marked (status_blood_feud), and the mark MOVES: the next
-- foe to hit a goblin takes it and the old one is cleared. That single rule is the whole lever the company
-- holds over a warband -- open with the body you want them to chase, or hit from the far side and watch them
-- turn and run across the board to get at the new Feud.
--
-- The mark is stamped with the side that holds the grudge (`feudSide`), so a hired goblin in the company and
-- a warband across the board keep a Feud each without clearing one another's. Pure logic, no love.graphics.
local Status = require("models.status")

local Feud = {}

Feud.STATUS = "status_blood_feud"

-- The unit `side` holds its Feud against, or nil.
function Feud.of(combat, side)
    for _, u in ipairs((combat and combat.units) or {}) do
        if u.alive then
            local s = Status.get(u, Feud.STATUS)
            if s and s.feudSide == side then return u end
        end
    end
    return nil
end

-- Does `unit`'s side hold its Feud against `target`?
function Feud.isFeudOf(unit, target)
    if not (unit and target) then return false end
    local s = Status.get(target, Feud.STATUS)
    return s ~= nil and s.feudSide == unit.side
end

-- Mark `target` as the Feud of `marker`'s side, clearing the side's old one. `marker` is the goblin that was
-- struck (or the Hobgoblin naming its enemy), and rides in as the status's applier.
function Feud.mark(combat, target, marker)
    if not (combat and target and target.alive and marker) or target.side == marker.side then return end
    local old = Feud.of(combat, marker.side)
    if old == target then
        Status.apply(combat, target, Feud.STATUS, { applier = marker }) -- a refresh
        return
    end
    if old then Status.remove(combat, old, Feud.STATUS) end
    Status.apply(combat, target, Feud.STATUS, { applier = marker })
end

return Feud
