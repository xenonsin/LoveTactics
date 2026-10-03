-- MEDUSA, THE GORGON: Envy's approach-floor elite (reviewed 2026-10-01..03, "Envy's Bestiary", row md_body,
-- approved). Cursed out of a goddess's jealousy, and envious now of every living face. Her four rules, and where
-- each one runs:
--
--   STONE GAZE   a body of the company that ENDS ITS TURN in her sight within 4 gains Stone (status_stone). At 3
--                Stone it is Petrified for 2 turns (status_petrified): it cannot act and takes half damage. The
--                threshold lives in the Stone status itself, so the Gorgon's Gaze (her shaman drop) petrifies by
--                the same rule. "In her sight" is a clear line from any cell of her body (Combat.unitHasSight), so
--                the waste's thin rock ridges are the answer.
--   BLOOD        a slashing blow that cuts her makes an adder spring up beside her (character_adder, a small
--                poisoner). Serpent Locks, the poisoner drop, carries the same rule for its wearer.
--   HER GARDEN   three statues of past challengers stand on the board (character_stone_challenger), Petrified
--                and held so; at her half health they crack open and fight.
--   PERSEUS      a body carrying the Hand-Mirror or the Polished Shield gains no Stone from her gaze, and turns it
--                back on her -- she gains it instead, and at 3 she is Petrified like anybody.
--
-- THE COUNTERPLAY, STATED: break her sight behind the ridges; cut her with anything but blades; and bring a
-- mirror.
--
-- Pure logic, headless-safe; Combat is reached lazily.

local Status = require("models.status")
local Fairest = require("models.fairest")

local Gorgon = {}

Gorgon.STONE = "status_stone"
Gorgon.PETRIFIED = "status_petrified"
Gorgon.ADDER = "character_adder"
Gorgon.GAZE_RANGE = 4
-- Living adders one body's blood keeps on the board at once. The page set no cap; a company of blades would
-- otherwise fill the waste with snakes faster than any of them could be killed, so the blood is held to four.
Gorgon.MAX_ADDERS = 4
-- The Polished Shield is slice B's (the Mirror-Knight's drop). It is named by id here and by the `perseus` flag
-- on the Hand-Mirror; whichever lands first, the other still answers.
Gorgon.PERSEUS_IDS = { armor_polished_shield = true }

local function C() return require("models.combat") end
local function name(u) return (u and u.char and u.char.name) or "it" end

-- Does `unit` carry a mirror the gaze turns on? A grid item flagged `perseus`, or the Polished Shield by id.
function Gorgon.mirrored(unit)
    local char = unit and unit.char
    if not (char and char.inventory) then return nil end
    -- Read off the BLUEPRINT: Item.instantiate copies a whitelist, and the flag is a fact about what the piece is.
    local defs = require("models.item").defs
    for _, item in ipairs(require("models.character").eachItem(char)) do
        local def = defs[item.id]
        if item.perseus or (def and def.perseus) or Gorgon.PERSEUS_IDS[item.id] then return item end
    end
    return nil
end

function Gorgon.giveStone(combat, unit, applier)
    if not (unit and unit.alive) or Status.has(unit, Gorgon.PETRIFIED) then return nil end
    return Status.apply(combat, unit, Gorgon.STONE, { applier = applier })
end

-- STONE GAZE: `actor` just ended its turn. Within 4 of her and in her sight, it gains Stone -- or, carrying a
-- mirror, she does.
function Gorgon.gaze(combat, medusa, actor)
    if not (medusa and medusa.alive and actor and actor.alive and actor.side ~= medusa.side) then return end
    if actor.summoned and actor.timeless then return end
    local Combat = C()
    if Combat.isOffTile(actor) or Combat.unitGap(medusa, actor) > Gorgon.GAZE_RANGE then return end
    local seen = false
    for _, c in ipairs(Combat.unitCells(actor)) do
        if Combat.unitHasSight(combat, medusa, c.x, c.y) then seen = true break end
    end
    if not seen then return end
    local mirror = Gorgon.mirrored(actor)
    if mirror then
        Combat.logEvent(combat, "status", string.format("%s's %s turns the gaze back on %s.",
            name(actor), mirror.name or "mirror", name(medusa)), { actor, medusa })
        Gorgon.giveStone(combat, medusa, actor)
        return
    end
    Gorgon.giveStone(combat, actor, medusa)
end

local function hasTag(tags, want)
    for _, t in ipairs(tags or {}) do if t == want then return true end end
    return false
end

local function adderCount(combat, bearer)
    local n = 0
    for _, u in ipairs(combat.units or {}) do
        if u.alive and u.summoner == bearer and u.char and u.char.id == Gorgon.ADDER then n = n + 1 end
    end
    return n
end

-- BLOOD: a slashing blow that cut `bearer` -- an adder springs up on an open tile beside it. Returns the adder.
function Gorgon.blood(combat, bearer, tags, amount)
    if not (bearer and bearer.alive) or (amount or 0) <= 0 or not hasTag(tags, "slash") then return nil end
    if adderCount(combat, bearer) >= Gorgon.MAX_ADDERS then return nil end
    local Combat = C()
    local best
    for _, c in ipairs(Combat.unitCells(bearer)) do
        local x, y = Combat.openTileNear(combat, c.x, c.y)
        if x then best = { x = x, y = y } break end
    end
    if not best then return nil end
    local adder = require("models.summon").spawn(combat, bearer, Gorgon.ADDER, best.x, best.y, { announce = false })
    if adder and adder.alive then
        Combat.logEvent(combat, "action", string.format("An adder springs up out of %s's blood.", name(bearer)),
            { bearer, adder })
    end
    return adder
end

-- HER GARDEN: the statues standing on her side crack open. Returns how many woke.
function Gorgon.wakeGarden(combat, medusa)
    local Trait = require("models.trait")
    local n = 0
    for _, u in ipairs(combat.units or {}) do
        if u.alive and u.side == medusa.side and u ~= medusa and Trait.flag(u, "dormantStatue") and not u.statueWoken then
            u.statueWoken = true
            Status.remove(combat, u, Gorgon.PETRIFIED)
            n = n + 1
        end
    end
    if n > 0 then
        C().logEvent(combat, "action", "The statues in her garden crack open, and the challengers step down.", medusa)
    end
    return n
end

-- A statue still waiting: held Petrified, refreshed at the end of each of its turns so the badge never quotes an
-- infinite hourglass. Once woken it is a challenger like any other.
function Gorgon.holdStatue(combat, statue)
    if statue.statueWoken or not statue.alive then return end
    Status.apply(combat, statue, Gorgon.PETRIFIED, { duration = 10 })
end

-- THE HAND-MIRROR: while its bearer holds more blessings than any ally -- and at least one -- a single-target
-- attack on it rebounds onto the attacker (Combat's tryWardSpell, beside Reflect Magic and Reflect Steel).
-- Returns the mirror (its name rides the log line) or nil.
function Gorgon.handMirror(combat, unit)
    if not (combat and unit and unit.alive and unit.traits) then return nil end
    local t = require("models.trait").flag(unit, "mirrorWhileFairest")
    if not t then return nil end
    local mine = Fairest.blessings(unit)
    if mine < 1 then return nil end
    for _, u in ipairs(combat.units or {}) do
        if u ~= unit and u.alive and u.side == unit.side and Fairest.blessings(u) >= mine then return nil end
    end
    return { id = "utility_hand_mirror", name = (t.item and t.item.name) or "Hand-Mirror" }
end

return Gorgon
