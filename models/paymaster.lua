-- THE PAYMASTER: the rules of Greed's one elite that is not what it looks like. Reviewed over four rounds on
-- 2026-09-25/26 ("The Paymaster"). The encounter is data/encounters/encounter_greed_the_paymaster.lua; the
-- two faces are data/characters/character_the_paymaster.lua and character_the_lure.lua.
--
-- VESH SALTED THE DEEP SEAMS WITH GOLD TO DRAW GREEDY DWARVES DOWN FOR FRESH BODIES, and this is the hand
-- that throws it: a shade of his own in a dead dwarf's shape, walking with a living crew and paying it into
-- the ground. Three acts, each reached from a live hook and never from an item effect's body, because a
-- preview replays that body against the real board (models/golem.lua makes the same argument):
--
--   PAY OUT     at the start of each of his turns a coin heap lands on an open tile within PAY_REACH of a
--               living dwarf of his crew (status_pay_out). The crew goes for it, pockets it and sickens --
--               three stacks and a dwarf is a Gilt Wyrm (status_dragon_sickness). He never pockets one: he
--               carries no Stout (`raceGrants = false`), and that is the fight's only tell.
--   THE REVEAL  the moment the last OTHER dwarf of his crew falls (trait_the_payroll), he stops paying and
--               turns (models/transform.lua -- the same machinery a sick dwarf turns with): the same unit on
--               the same tile, in the same place in the turn, on the same health bar, in the shade's body.
--               Killed first, he dies as the Paymaster and nothing rises.
--   THE RAISE   once, as part of the reveal: every dwarf of his crew that fell in this fight stands up where
--               it fell, on his side -- a Dwarf Skeleton, or a Bone Wyrm if it fell as a Gilt Wyrm -- until
--               his side stands at the elite cap. The rest stay in the ground. The dead forget the gold
--               (trait_stout's `deadForget`; the Bone Wyrm carries no Stout at all), so the heaps he threw
--               are the company's alone from then on.
--
-- WHO COUNTS AS A DWARF is asked of what a body WAS BORN (a Gilt Wyrm is still a dwarf under the scales --
-- Transform.originalChar) and never of a dead one (a skeleton is not crew). A charmed crewman still counts
-- while it is taken; his own side is the rest of the answer.
--
-- Pure logic, headless-safe. Combat, Hazard, Status and Transform are reached lazily, as models/golem.lua
-- reaches them: this file is required from blueprints that load while models/combat.lua is still loading.
local Character = require("models.character")

local Combat = setmetatable({}, { __index = function(_, k) return require("models.combat")[k] end })
local Hazard = setmetatable({}, { __index = function(_, k) return require("models.hazard")[k] end })
local Status = setmetatable({}, { __index = function(_, k) return require("models.status")[k] end })
local Transform = setmetatable({}, { __index = function(_, k) return require("models.transform")[k] end })

local Paymaster = {}

-- How far from a living dwarf a thrown heap lands (Manhattan, as every reach in the game is measured).
Paymaster.PAY_REACH = 2
-- What a fallen dwarf rises as, and what a fallen wyrm does.
Paymaster.SKELETON = "character_dwarf_skeleton"
Paymaster.WYRM = "character_gilt_wyrm"
Paymaster.BONE_WYRM = "character_bone_wyrm"
-- The status that carries Pay Out, and the trait whose bearer is the Paymaster.
Paymaster.PAY_STATUS = "status_pay_out"
Paymaster.PAYROLL = "trait_the_payroll"

local function name(u) return (u and u.char and u.char.name) or "It" end

-- What a body walked into the fight as: its own char, or the one under the shape it is wearing.
local function bornAs(unit)
    return unit and (Transform.originalChar(unit) or unit.char)
end

-- A DWARF, in this fight's sense: born one, and not dead. A Gilt Wyrm answers yes; a skeleton answers no.
function Paymaster.isDwarf(unit)
    local c = bornAs(unit)
    return c ~= nil and c.race == "dwarf" and not Character.isUndead(c)
end

-- Is `unit` a Paymaster (the payroll is what makes one)? He wears the dwarf race and is not crew.
function Paymaster.isPaymaster(unit)
    return unit ~= nil and require("models.trait").has(unit, Paymaster.PAYROLL)
end

-- Is `u` one of `pay`'s crew: a dwarf standing on his side, or one of them taken by a charm.
local function isCrew(pay, u)
    if u == pay or Paymaster.isPaymaster(u) or not Paymaster.isDwarf(u) then return false end
    return u.side == pay.side or Status.has(u, "status_charm")
end

-- The living crew, in board order.
function Paymaster.crew(combat, pay)
    local out = {}
    for _, u in ipairs((combat and combat.units) or {}) do
        if u.alive and isCrew(pay, u) then out[#out + 1] = u end
    end
    return out
end

-- Is he still wearing the dwarf? False once he has turned.
function Paymaster.disguised(pay)
    return pay ~= nil and not Transform.isTransformed(pay)
end

-- The open tiles within PAY_REACH of `dwarf` -- walkable, nobody and nothing on them, no ground laid there
-- (models/golem.lua's own test for where a heap may land).
local function payTiles(combat, dwarf)
    local Golem = require("models.golem")
    local out = {}
    local r = Paymaster.PAY_REACH
    for dy = -r, r + (dwarf.h or 1) - 1 do
        for dx = -r, r + (dwarf.w or 1) - 1 do
            local x, y = dwarf.x + dx, dwarf.y + dy
            local gap = Combat.cellGap(x, y, dwarf)
            if gap >= 1 and gap <= r and Golem.clear(combat, x, y) then out[#out + 1] = { x = x, y = y } end
        end
    end
    return out
end

-- PAY OUT: one heap on an open tile within reach of one living crewman, both picked on the fight's own
-- dice. Returns the tile, or nil when there is nobody left to pay or nowhere to throw it.
function Paymaster.payOut(combat, pay)
    if not (combat and pay and pay.alive) or not Paymaster.disguised(pay) then return nil end
    local crew = Paymaster.crew(combat, pay)
    if #crew == 0 then return nil end
    local dwarf = crew[Combat.roll(combat, #crew)]
    local tiles = payTiles(combat, dwarf)
    if #tiles == 0 then return nil end
    local t = tiles[Combat.roll(combat, #tiles)]
    if not Hazard.place(combat, t.x, t.y, "hazard_coin_heap", {}) then return nil end
    Combat.logEvent(combat, "action", string.format("%s pays out: gold lands at %s's feet.", name(pay), name(dwarf)),
        { pay, dwarf })
    return t
end

-- THE RAISE: every crew dwarf that fell in this fight, standing up where it fell, on `pay`'s side, while his
-- side stands under the elite cap. Board order decides who when there is not room for everybody. Returns the
-- raised units.
function Paymaster.raise(combat, pay)
    local Arena = require("models.arena")
    local Growth = require("models.growth")
    local standing = 0
    local fallen = {}
    for _, u in ipairs(combat.units) do
        if u.alive and u.side == pay.side then standing = standing + 1 end
        -- A BODY ON THE TILE: downed or a corpse. A summon, a decoy, a drowned or a devoured dwarf left none.
        if not u.alive and u ~= pay and u.side == pay.side and Paymaster.isDwarf(u)
            and not u.summoned and not u.decoyOf and not u.sank and not u.devoured
            and (u.incapacitated or u.corpse) then
            fallen[#fallen + 1] = u
        end
    end

    local raised = {}
    for _, body in ipairs(fallen) do
        if standing >= Arena.ELITE_CAP then break end
        local wyrm = Transform.isTransformed(body) and body.char and body.char.id == Paymaster.WYRM
        local id = wyrm and Paymaster.BONE_WYRM or Paymaster.SKELETON
        local x, y = body.x, body.y
        if not Combat.footprintFree(combat, 1, 1, x, y) then x, y = Combat.openTileNear(combat, x, y) end
        if x then
            -- The body is spent, as a devoured one is: nothing is left on the tile to revive or raise again.
            if body.incapacitated then
                Status.remove(combat, body, "status_downed")
                body.incapacitated = false
            end
            body.corpse = false
            local level = (bornAs(body) or {}).level or (pay.char and pay.char.level) or 1
            local unit = Combat.addUnit(combat, Growth.atLevel(id, level), pay.side, x, y, { control = "ai" })
            Combat.logEvent(combat, "action", string.format("%s gets up again, and it is his now.", name(unit)),
                { pay, unit })
            Combat.enterTile(combat, unit, x, y)
            standing = standing + 1
            raised[#raised + 1] = unit
        end
    end
    return raised
end

-- THE REVEAL. Stops the pay, puts him in his own body, stamps the face the company has now seen onto the
-- character it walked in against (Bestiary.recordMet reads `unmasked`), and raises the crew. Returns true
-- when he turned.
function Paymaster.reveal(combat, pay)
    if not (combat and pay and pay.alive) or not Paymaster.disguised(pay) then return false end
    local original = pay.char
    local def = Character.defs[original.id]
    local shapeId = def and def.unmasks
    if not shapeId then return false end
    Status.remove(combat, pay, Paymaster.PAY_STATUS)
    local shape = Transform.apply(combat, pay, shapeId, { level = original.level })
    if not shape then return false end
    original.unmasked = shapeId
    Combat.logEvent(combat, "action", string.format("The last of the crew is down, and %s was never one of them.",
        original.name or "the Paymaster"), pay)
    Paymaster.raise(combat, pay)
    return true
end

-- A body fell somewhere on the board (trait_the_payroll's onAnyDeath). Turns him the moment the one that fell
-- was the last of his crew.
function Paymaster.onFall(combat, pay, fallen)
    if not (fallen and pay and pay.alive) or not Paymaster.disguised(pay) then return false end
    if fallen.side ~= pay.side or not Paymaster.isDwarf(fallen) or Paymaster.isPaymaster(fallen) then return false end
    if #Paymaster.crew(combat, pay) > 0 then return false end
    return Paymaster.reveal(combat, pay)
end

-- The turn's opening (status_pay_out): a crew already gone -- a fall the payroll did not hear, a Sundered
-- turn -- turns him here instead; otherwise he pays out.
function Paymaster.turnStart(combat, pay)
    if not (combat and pay and pay.alive) or not Paymaster.disguised(pay) then return end
    if #Paymaster.crew(combat, pay) == 0 then
        Paymaster.reveal(combat, pay)
        return
    end
    Paymaster.payOut(combat, pay)
end

return Paymaster
