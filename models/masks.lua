-- MASKS AND MIRRORS: the Faceless of Envy's seat that choose a face some other way than Reshape, and the pool
-- they come out of. Reviewed over three rounds (2026-10-01..03, "Envy's Bestiary"); slice B of the build.
--
--   THE DOPPELGANGER   at the opening bell it becomes an exact copy of the nearest of the company -- stats, the
--                      whole grid, and the tactics that body fights with -- and keeps it until it dies
--   THE COLOSSUS       wears two faces at once: the one Reshape picks, and the runner-up's kit folded into the
--                      cells the first face leaves free
--   THE MASK-MAKER     each turn it hands every Faceless within 3 a face from its own hand, all different, to
--                      build a company: a shield, a healer, an archer and a caster
--   THE WATER MIRROR   at the opening bell it stands an exact copy of every body in the company; it cannot be
--                      hurt while one stands, and a copy is never hurt by its own original and goes for it first
--
-- ALL FOUR SIT ON A THOUSAND FACES (models/faces.lua). A face is still a transform: the body's own health pool
-- crosses into every shape, so none of this changes how much killing a body takes. `unit.faceLocked` is the
-- one switch they share -- set, Reshape stands aside -- and the Mask-Maker's assignments carry `maskedBy` so its
-- death hands exactly those bodies back to Reshape, never a Doppelganger it did not lock.
--
-- Pure logic (no love.graphics), so it loads under the headless tests. Combat, Status and the rest are reached
-- lazily: models/status.lua asks Masks.ward on every blow and this file needs Status back.

local Character = require("models.character")
local Item = require("models.item")

local Masks = {}

-- ------------------------------------------------------------------------------------------ the copy

-- The TACTICS a copy carries: the posture it fights in and the rule list it decides by -- the player's own
-- overlay (`aiRules`) when the original has one, which is what makes a copy of your healer heal the way you
-- told yours to. Summon.copyChar copies the body and the grid; this is the third thing "an exact copy" owes.
function Masks.copyTactics(into, from)
    if not (into and from) then return into end
    into.archetype = from.archetype
    into.ai = from.ai
    into.aiRules = from.aiRules
    return into
end

-- An exact copy of `src` (a char): stats, every item in the grid, and its tactics.
function Masks.exactCopy(src)
    return Masks.copyTactics(require("models.summon").copyChar(src), src)
end

-- The nearest living body of the other side that is a body in its own right (no summon, no copy), or nil.
function Masks.nearestOriginal(combat, unit)
    local Combat = require("models.combat")
    local best, bestGap
    for _, u in ipairs(combat.units or {}) do
        if u.alive and u.side ~= unit.side and not u.summoned then
            local gap = Combat.unitGap(unit, u)
            if not bestGap or gap < bestGap then best, bestGap = u, gap end
        end
    end
    return best
end

-- THE DOPPELGANGER'S RULE. Wears an exact copy of the nearest of the company and locks it there, so no read
-- takes it off again. Returns the body copied, or nil when there was nobody to copy.
function Masks.becomeNearest(combat, unit)
    if not (unit and unit.alive) then return nil end
    local target = Masks.nearestOriginal(combat, unit)
    if not target then return nil end
    -- Its own lock, not a Mask-Maker's: a mask handed out before this opener fired is taken back off the books, so
    -- the Mask-Maker's next turn neither releases the copy nor masks over it.
    unit.faceLocked, unit.maskedBy, unit.maskRole = true, nil, nil
    if not require("models.faces").wear(combat, unit, Masks.exactCopy(target.char)) then return nil end
    -- The copy's own tactics, onto the shape just put on (Faces.wear rebuilt the grid around it).
    Masks.copyTactics(unit.char, target.char)
    unit.copyOf = target
    return target
end

-- ------------------------------------------------------------------------------------------ two faces

-- THE COLOSSUS'S SECOND FACE. A transform holds one shape, so "two faces at once" is built as the smallest
-- thing that reads as both: the face Reshape put on is the body (its name, stats and grid), and the RUNNER-UP
-- for the same read -- the second-best face in the hand for the form asked -- lends its kit, folded into
-- whatever cells the first face left free. The lent pieces are marked, so a fresh read strips the old ones
-- before folding the new. Returns the second face's id, or nil.
function Masks.secondFace(unit)
    local Faces = require("models.faces")
    local form = unit.faceForm or "blade"
    local best, bestScore
    for _, id in ipairs(unit.faceHand or {}) do
        if id ~= unit.faceWorn then
            local sc = Faces.score(id, form)
            if not bestScore or sc > bestScore then best, bestScore = id, sc end
        end
    end
    return best
end

function Masks.foldSecondFace(combat, unit)
    if not (unit and unit.alive and unit.faceWorn) then return nil end
    local Combat = require("models.combat")
    local Trait = require("models.trait")
    local Faces = require("models.faces")
    local second = Masks.secondFace(unit)
    if not second then return nil end
    if unit.secondFace == second and unit._secondFaceShape == unit.char then return second end
    -- Strip what the last second face lent, wherever it sits.
    for i = 1, Character.MAX_INVENTORY do
        local item = unit.char.inventory[i]
        if item and item.lentByFace then unit.char.inventory[i] = nil end
    end
    local level = unit.char.level
    local body = level and require("models.growth").atLevel(second, level) or Character.instantiate(second)
    for _, item in ipairs(Character.eachItem(body)) do
        if not item.bound then
            local copy = Item.instantiate(item.id, item.quantity)
            copy.lentByFace = true
            Character.addItem(unit.char, copy)
        end
    end
    -- The heap keeps its own four tiles under every face: the board reads the footprint off the char it wears.
    unit.char.footprint = Faces.originalChar(unit).footprint
    Combat.refreshPassives(unit)
    Trait.attach(unit, combat)
    unit.secondFace = second
    unit._secondFaceShape = unit.char
    return second
end

-- ------------------------------------------------------------------------------------------ the masks

-- THE FOUR FACES OF A COMPANY, in the order the Mask-Maker hands them out (nearest Faceless first, so the
-- shield goes to whoever is already in front). Each is read off the face's own kit, the way the planner reads
-- a healer (AI's support weight): a body is a healer because it carries a repeatable support ability.
Masks.ROLES = { "shield", "healer", "archer", "caster" }
Masks.REACH = 3   -- how far the Mask-Maker's hand reaches
Masks.ARCHER_REACH = 3

local roleCache = {}

function Masks.roleOf(id)
    if roleCache[id] ~= nil then return roleCache[id] or nil end
    local Combat = require("models.combat")
    local char = Character.instantiate(id)
    local s = char.stats or {}
    local heals = char.archetype == "support"
    for _, item in ipairs(Combat.abilityItems(char)) do
        local ab = item.activeAbility
        if ab and Combat.isSupportAbility(ab) and not ab.consumesItem and item.type ~= "consumable" then
            heals = true
        end
    end
    local act = Combat.defaultAction(char)
    local reach = (act and act.activeAbility and act.activeAbility.range) or 1
    local role
    if heals then role = "healer"
    elseif (s.magicDamage or 0) > (s.damage or 0) then role = "caster"
    elseif reach >= Masks.ARCHER_REACH then role = "archer"
    else role = "shield" end
    roleCache[id] = role
    return role
end

-- Deal the Mask-Maker's hand: one face per role off the fight's own seeded roll, the shield the best Bulwark
-- of a small draw so the front of the company stands up. Stored as `unit.faceHand` (Reshape reads it for the
-- Mask-Maker's own face) with `unit.maskRoles` naming which is which.
function Masks.dealCompany(combat, unit)
    local Combat = require("models.combat")
    local Faces = require("models.faces")
    local byRole = {}
    for _, id in ipairs(Faces.eligible()) do
        local r = Masks.roleOf(id)
        byRole[r] = byRole[r] or {}
        table.insert(byRole[r], id)
    end
    local hand, roles = {}, {}
    for _, role in ipairs(Masks.ROLES) do
        local deck = byRole[role] or {}
        if #deck > 0 then
            hand[#hand + 1] = deck[Combat.roll(combat, #deck)]
            roles[#roles + 1] = role
        end
    end
    unit.faceHand, unit.maskRoles = hand, roles
    return hand
end

-- Is `other` a Faceless the Mask-Maker may mask? Of its side, standing, wearing the race's badge -- and not
-- holding a face some other rule chose (a Doppelganger's copy; another Mask-Maker's assignment).
local function maskable(maker, other)
    if not (other and other.alive and other ~= maker and other.side == maker.side) then return false end
    -- The badge, or the race's trait for a body whose own opener has not fired yet (Trait.setup walks the board
    -- in order, and the squad may be seated after the Mask-Maker).
    local Faces = require("models.faces")
    if not (require("models.status").has(other, Faces.STATUS)
        or require("models.trait").has(other, "trait_a_thousand_faces")) then
        return false
    end
    if other.faceLocked and other.maskedBy ~= maker then return false end
    return true
end

-- Hand every body it masked back to Reshape. Called when it dies, and at the top of each of its turns before
-- it hands the masks out again (a body that has walked out of reach reads for itself once more).
function Masks.release(combat, maker)
    for _, u in ipairs(combat.units or {}) do
        if u.maskedBy == maker then
            u.maskedBy, u.faceLocked, u.maskRole = nil, nil, nil
        end
    end
end

-- THE MASK-MAKER'S RULE. Hands each Faceless within reach a face from its own hand, all different, nearest
-- first in the order of Masks.ROLES. Returns the list of { unit, face, role } handed out.
function Masks.handOut(combat, maker)
    if not (maker and maker.alive and maker.faceHand) then return {} end
    local Combat = require("models.combat")
    local Faces = require("models.faces")
    Masks.release(combat, maker)
    local squad = {}
    for _, u in ipairs(combat.units or {}) do
        if maskable(maker, u) and Combat.unitGap(maker, u) <= Masks.REACH then squad[#squad + 1] = u end
    end
    -- Nearest first; board order breaks a tie, so the deal is the same on every machine.
    local order = {}
    for i, u in ipairs(combat.units) do order[u] = i end
    table.sort(squad, function(a, b)
        local ga, gb = Combat.unitGap(maker, a), Combat.unitGap(maker, b)
        if ga ~= gb then return ga < gb end
        return order[a] < order[b]
    end)
    local out = {}
    for i, u in ipairs(squad) do
        local face = maker.faceHand[i]
        if not face then break end
        u.faceLocked, u.maskedBy, u.maskRole = true, maker, (maker.maskRoles or {})[i]
        Faces.wear(combat, u, face)
        out[#out + 1] = { unit = u, face = face, role = u.maskRole }
    end
    if #out > 0 then
        Combat.logEvent(combat, "status", string.format("%s hands out its masks.",
            (maker.char and maker.char.name) or "The Mask-Maker"), maker)
    end
    return out
end

-- ------------------------------------------------------------------------------------------ the pool

-- THE WATER MIRROR'S RULE. An exact copy of every body in the company, fielded on the pool's side around it,
-- each one knowing its original (`mirrorOf`). Sustained by the pool, so its death unmakes any that stand --
-- which can only happen once none do. Returns the copies.
function Masks.mirrorCompany(combat, pool)
    local Combat = require("models.combat")
    local Summon = require("models.summon")
    local originals = {}
    for _, u in ipairs(combat.units or {}) do
        if u.alive and u.side ~= pool.side and not u.summoned then originals[#originals + 1] = u end
    end
    local copies = {}
    for _, orig in ipairs(originals) do
        local x, y = Combat.openTileNear(combat, pool.x, pool.y)
        if not x then
            -- The ring is full: widen to the ring around the copies already stood.
            for _, c in ipairs(copies) do
                x, y = Combat.openTileNear(combat, c.x, c.y)
                if x then break end
            end
        end
        if x then
            local copy = Summon.copyOf(combat, pool, orig, x, y)
            if copy then
                Masks.copyTactics(copy.char, orig.char)
                copy.mirrorOf = orig
                copy.knows = orig
                copies[#copies + 1] = copy
            end
        end
    end
    pool.mirrorCopies = copies
    return copies
end

-- Does a copy the pool made still stand?
function Masks.copyStands(pool)
    for _, c in ipairs(pool.mirrorCopies or {}) do
        if c.alive then return true end
    end
    return false
end

local UNBROKEN = { id = "unbroken_surface", name = "Unbroken Surface" }
local KNOWN = { id = "knows_its_original", name = "Knows You" }

-- The ward that voids a blow on `unit` struck by `attacker`, or nil. Read by Status.immuneToDamage (beside
-- Pride's wards), so the forecast, the log and the blow agree:
--   * the pool takes nothing while a copy it made stands;
--   * a body that KNOWS its attacker (a Water Mirror copy and its original; a Still Water copy and the foe
--     named when it was made) takes nothing from that one body.
function Masks.ward(unit, attacker)
    if not unit then return nil end
    if attacker and unit.knows == attacker then return KNOWN end
    if unit.mirrorCopies and Masks.copyStands(unit) then return UNBROKEN end
    return nil
end

return Masks
