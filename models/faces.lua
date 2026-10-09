-- The Faceless: bodies that wear other bodies. Envy's seat line, reviewed over three rounds (2026-10-01..03,
-- "Envy's Bestiary"): "faceless could take the appearance and abilities of ANY character in the game".
--
-- A FACE IS A CHARACTER. A Faceless carries a HAND of them (`unit.faceHand`, a list of character ids) and wears
-- one at a time through Transform.apply: that character's name, sprite, flat stats and whole grid, signature
-- rules included. Its own health pool carries across (the transform's continuity rule), so a face changes what
-- a Faceless DOES and never how much killing it takes -- every face in the bestiary is balanced on one axis.
--
-- RESHAPE IS THE CHOOSER (approved round 1, kept round 2). At the top of its turn a Faceless reads the nearest
-- of the other side and asks one of three questions, in order:
--   * BULWARK -- that body hits harder than this one does: wear the face that stands up best;
--   * HUNTER  -- that body fights from range (its default action reaches 3+): wear the fastest, or a ranged face;
--   * BLADE   -- otherwise: wear the face that hits hardest.
-- The read is the player's lever: whoever stands nearest decides what the Faceless becomes.
--
-- WHAT A FACE MAY BE. Any body the bestiary holds, minus five kinds that would break the rule or the board:
-- generals and stair bosses (`boss`, `character_general_*`) are fights, not faces; anything wider than one tile
-- would need a footprint the Faceless does not have; objects and tier-0 husks are not fighters; a health-1
-- blueprint is a Wild Shape a druid wears, not a body; and humans are off the rift's rolls (the human companies
-- were deleted), which also keeps every companion's own blueprint out of a stranger's hand. The Faceless
-- themselves are excluded so a hand never nests.
--
-- A BODY'S OWN RULES SURVIVE ITS FACES. A transform rebuilds the grid from the shape, which would strip a
-- Faceless of the very organ that makes it one. Faces.wear carries every BOUND creature item (an organ) from
-- the original body into each shape it puts on, so the Assassin is still the Assassin in an orc's face. The
-- turn-top read itself rides on a status (status_faceless), which a transform never touches.
--
-- Pure logic (no love.graphics), so it loads under the headless tests.

local Character = require("models.character")
local Item = require("models.item")

local Faces = {}

Faces.ORGAN = "utility_faceless_blood"
Faces.STATUS = "status_faceless"
Faces.RACE = "faceless"
Faces.HAND = 3 -- the line soldier's hand, and the default for a body that names no other

local function defaultReach(def)
    for _, id in ipairs(def.startingItems or {}) do
        if id and id == def.defaultAction then
            local item = Item.defs[id]
            local ab = item and item.activeAbility
            return (ab and ab.range) or 1
        end
    end
    local item = def.defaultAction and Item.defs[def.defaultAction]
    local ab = item and item.activeAbility
    return (ab and ab.range) or 1
end

-- May `id` be worn as a face? See the header for the five exclusions.
function Faces.isEligible(id)
    local def = Character.defs[id]
    if not def then return false end
    if (def.tier or 0) < 1 then return false end
    if def.race == "object" or def.race == "human" or def.race == Faces.RACE then return false end
    if def.boss or tostring(id):find("^character_general_") then return false end
    -- SLOTH'S DREAMERS (slice E): a body that never attacks (`neverAttacks`, the Old Spruce) is not a fighter, and
    -- a Faceless that put it on would stand rooted and swing at nothing for the rest of the fight.
    if def.neverAttacks then return false end
    -- THE RIFT'S ADVENTURERS, SLICE C (2026-10-09): an adventurer body is race-free, and its blueprint's
    -- `race` is only a placeholder that lets it load; it is never fielded as itself (models/adventurers.lua),
    -- so a Faceless must not put it on either.
    if def.adventurer then return false end
    local fp = def.footprint
    if fp and ((fp.w or 1) > 1 or (fp.h or 1) > 1) then return false end
    local hp = def.stats and def.stats.health
    if type(hp) ~= "number" or hp <= 1 then return false end
    return true
end

-- Every eligible face, sorted by id so a seeded deal is the same deal on every machine (a `pairs` walk is in
-- whatever order this build hashes the strings in).
local pool
function Faces.eligible()
    if pool then return pool end
    pool = {}
    for id in pairs(Character.defs) do
        if Faces.isEligible(id) then pool[#pool + 1] = id end
    end
    table.sort(pool)
    return pool
end

-- A face's place in one deal: a hash of the deal's salt and the face's own id, so where a face ranks depends on
-- nothing but itself. Plain arithmetic, no bit library (the web engine is Lua 5.1), and every product stays
-- under 2^53. The string pass folds the bytes; the Park-Miller rounds after it spread the fold, because the
-- pass alone ranks ids that share a prefix next to each other.
local function rank(salt, id)
    local s = tostring(salt) .. ":" .. tostring(id)
    local h = 5381
    for i = 1, #s do h = (h * 33 + s:byte(i)) % 4294967291 end
    h = h % 2147483647
    if h == 0 then h = 1 end
    for _ = 1, 3 do h = (h * 16807) % 2147483647 end
    return h
end

-- Deal `n` distinct faces into `unit.faceHand`, off the fight's own seeded roll. `from` narrows the deck (the
-- Champion's hand is the rift's champions, not the whole bestiary).
--
-- RANKED, NOT DRAWN BY POSITION (Sloth's Bestiary integration, 2026-10-04). The deal used to take `n` seeded
-- indices into the sorted deck, so every body added ANYWHERE in the bestiary shifted every index and re-dealt
-- every Faceless fight in the game -- each new circle silently re-measured Envy (slice E had to fence the Old
-- Spruce out, and the next line pushed The One Who Has Not Acted past the skirmish budget on a hand of three
-- faces none of which was new). Now the fight's roll is drawn ONCE as a salt and every face is ranked by its own
-- hash against it: a new body changes a hand only when it ranks into it.
function Faces.deal(combat, unit, n, from)
    local Combat = require("models.combat")
    local deck = {}
    for _, id in ipairs(from or Faces.eligible()) do
        if Character.defs[id] then deck[#deck + 1] = id end
    end
    n = math.min(n or Faces.HAND, #deck)
    local salt = Combat.roll(combat, 2147483646)
    local keyed = {}
    for _, id in ipairs(deck) do keyed[#keyed + 1] = { id = id, r = rank(salt, id) } end
    table.sort(keyed, function(a, b)
        if a.r ~= b.r then return a.r < b.r end
        return a.id < b.id
    end)
    local hand = {}
    for i = 1, n do hand[i] = keyed[i].id end
    unit.faceHand = hand
    return hand
end

-- The three questions a face answers, scored off its blueprint so a hand can be ranked for each.
local function score(id, form)
    local def = Character.defs[id]
    -- ENVY'S FACELESS, SLICE A: a face may be a BUILT body (a companion's, copied off the save or off the board
    -- -- models/stolen_faces.lua), whose pools are { max, current } and whose opening weapon is in its grid.
    if type(id) == "table" then
        local s = id.stats or {}
        local hp = type(s.health) == "table" and s.health.max or s.health
        if form == "bulwark" then return (s.defense or 0) + (s.magicDefense or 0) + (hp or 0) / 10 end
        if form == "hunter" then
            local act = id.inventory and require("models.combat").defaultAction(id)
            local reach = (act and act.activeAbility and act.activeAbility.range) or 1
            return (s.movement or 0) * 2 + (reach >= 3 and 10 or 0)
        end
        return math.max(s.damage or 0, s.magicDamage or 0)
    end
    -- end ENVY'S FACELESS, SLICE A
    local s = (def and def.stats) or {}
    if form == "bulwark" then return (s.defense or 0) + (s.magicDefense or 0) + (s.health or 0) / 10 end
    if form == "hunter" then
        return (s.movement or 0) * 2 + (defaultReach(def or {}) >= 3 and 10 or 0)
    end
    return math.max(s.damage or 0, s.magicDamage or 0)
end

function Faces.score(id, form) return score(id, form) end

-- The nearest living body on the other side, or nil.
function Faces.nearestFoe(combat, unit)
    local Combat = require("models.combat")
    local best, bestGap
    for _, u in ipairs(combat.units or {}) do
        if u.alive and u.side ~= unit.side and not u.summonedHidden then
            local gap = Combat.unitGap(unit, u)
            if not bestGap or gap < bestGap then best, bestGap = u, gap end
        end
    end
    return best
end

-- RESHAPE: which form answers `foe`. Its damage is read off its sheet (the stats it is fighting with now), and
-- its reach off the action it opens with.
function Faces.read(combat, unit, foe)
    local Combat = require("models.combat")
    foe = foe or Faces.nearestFoe(combat, unit)
    if not foe then return "blade" end
    local function hits(u)
        local s = u.char.stats
        return math.max(s.damage or 0, s.magicDamage or 0)
    end
    local own = Faces.originalChar(unit)
    local ownHits = math.max(own.stats.damage or 0, own.stats.magicDamage or 0)
    if hits(foe) > ownHits then return "bulwark" end
    local act = Combat.defaultAction(foe.char, foe)
    local ab = act and act.activeAbility
    if ab and (ab.range or 1) >= 3 then return "hunter" end
    return "blade"
end

-- The face in the hand that best answers `form`.
function Faces.pick(unit, form)
    local best, bestScore
    for _, id in ipairs(unit.faceHand or {}) do
        local sc = score(id, form)
        if not bestScore or sc > bestScore then best, bestScore = id, sc end
    end
    return best
end

-- The body underneath whatever it is wearing.
function Faces.originalChar(unit)
    return (unit._shape and unit._shape.char) or unit.char
end

-- Put on `face`: a character id from the bestiary, or a built char table (a companion's face, made with
-- Summon.copyChar). Takes off whatever it was wearing first, carries the body's own organs into the new shape,
-- and returns the shape (nil when it refuses).
function Faces.wear(combat, unit, face)
    if not (unit and unit.alive and face) then return nil end
    local Transform = require("models.transform")
    local Combat = require("models.combat")
    local Trait = require("models.trait")
    local id = type(face) == "table" and (face.id or face.name) or face
    if unit.faceWorn == id and Transform.isTransformed(unit) then return unit.char end
    if Transform.isTransformed(unit) then Transform.revert(combat, unit) end

    local organs = {}
    for _, item in ipairs(Character.eachItem(unit.char)) do
        if item.bound and item.class == "creature" then organs[#organs + 1] = item.id end
    end
    local level = unit.char.level
    local shape = Transform.apply(combat, unit, type(face) == "string" and face or nil,
        { level = level, char = type(face) == "table" and face or nil })
    if not shape then return nil end
    for _, organ in ipairs(organs) do
        local held = false
        for _, item in ipairs(Character.eachItem(unit.char)) do
            if item.id == organ then held = true break end
        end
        if not held then Character.addItem(unit.char, Item.instantiate(organ)) end
    end
    Combat.refreshPassives(unit)
    Trait.attach(unit, combat)
    unit.faceWorn = id
    -- ENVY'S FACELESS, SLICE A: announce the face (`onFaceWorn`), for a body whose rule turns on what it has just
    -- put on -- the Champion opens each face as it would have at the bell (models/stolen_faces.lua).
    Trait.fire(combat, unit, "onFaceWorn", { face = id })
    return shape
end

-- The turn-top rule (status_faceless calls this). A body that has its face chosen for it some other way
-- (`unit.faceLocked`: the Doppelganger's copy, a Mask-Maker's assignment) skips the read.
function Faces.reshape(combat, unit)
    if not (unit and unit.alive) or unit.faceLocked then return nil end
    if not unit.faceHand or #unit.faceHand == 0 then return nil end
    local form = Faces.read(combat, unit)
    unit.faceForm = form
    local face = Faces.pick(unit, form)
    if face then return Faces.wear(combat, unit, face) end
    return nil
end

return Faces
