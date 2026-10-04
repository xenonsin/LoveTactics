-- Bank: turns put by for later, kept as status_banked's count ("Sloth's Bestiary", 2026-10-04).
--
-- One small seam so every keeper -- the Ground Sloth, the Old Sloth, Desidia -- earns and spends the same way and
-- holds itself to its OWN cap. The status carries only the number (and a ceiling no keeper meets); the cap is the
-- body's, which is why it is an argument here rather than a field on the status.
--
-- Pure logic over Status, so it loads under the headless tests.
local Status = require("models.status")

local Bank = {}

Bank.STATUS = "status_banked"

-- How many turns `unit` has banked.
function Bank.count(unit)
    return Status.stacksOf(unit, Bank.STATUS)
end

-- Bank `n` (default 1) more turns on `unit`, never past `cap` (nil = no cap). Returns the new count.
function Bank.add(combat, unit, n, cap)
    local have = Bank.count(unit)
    local add = n or 1
    if cap then add = math.min(add, cap - have) end
    if add <= 0 then return have end
    Status.apply(combat, unit, Bank.STATUS, { magnitude = add, applier = unit })
    return Bank.count(unit)
end

-- Take one turn out of the bank (a jolt). Returns the new count.
function Bank.knock(combat, unit)
    local s = Status.get(unit, Bank.STATUS)
    if not s then return 0 end
    s.magnitude = (s.magnitude or 0) - 1
    if s.magnitude <= 0 then Status.remove(combat, unit, Bank.STATUS) return 0 end
    return s.magnitude
end

-- Spend the whole bank: returns how many turns were banked and takes the badge off.
function Bank.spend(combat, unit)
    local have = Bank.count(unit)
    if have > 0 then Status.remove(combat, unit, Bank.STATUS) end
    return have
end

return Bank
