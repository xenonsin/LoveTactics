-- THE STRAY DELVER: the one body every escort, defend and rescue in the rift is fought over.
--
-- Approved 2026-10-21 in the objective pass ("One escort body: the Stray Delver"): a hurt member of some
-- OTHER adventuring company -- the rift is full of them (models/adventurers.lua) -- rolled per fight the
-- way a hire is rolled (class + people, models/hire.lua), never speaking, posted where it stands
-- (`holdGround`). One body rather than one per fight, so a stranger in trouble is a thing the player
-- learns to read once.
--
-- AUTHORED AS A PLAIN ID, ROLLED AT THE BOARD. An encounter writes `allies = { "character_stray_delver" }`
-- and points its objective at the same id (`protect`, `who`, `captive`). Arena.build swaps each one for
-- a rolled `character_stray_delver@<class>.<race>.<roll>` off the fight's own seed BEFORE anything is
-- seated, and rewrites the objective's fields to match -- so the protect clause, the escort's walk and
-- the HUD's "keep Bryn alive" all name the body actually standing there, and one seed still reproduces
-- the fight body for body. The bare id is a real blueprint too (data/characters/character_stray_delver
-- .lua): anything that rates a fight without seating it (models/muster.lua) gets a body back.
--
-- The variant is a HIRE'S BODY with the delver's posture: the same zero-sum spread, the same rung-0 kit,
-- the same name list -- a stranger off the Lodge's board and a stranger bleeding in a web are the same
-- kind of person. Not a hire: it carries no `hire` flag, so it never reaches a roster, a save or a board.
local Seed = require("models.seed")

local Delver = {}

Delver.ID = "character_stray_delver"
Delver.PREFIX = Delver.ID .. "@"

-- The classes a delver walks in as: the seven roots, sorted so a seed deals the same list the same way.
local function roots()
    local Hire = require("models.hire")
    local list = {}
    for class in pairs(Hire.ROOT_TEMPLATE) do list[#list + 1] = class end
    table.sort(list)
    return list
end

function Delver.isDelver(idOrChar)
    local id = type(idOrChar) == "table" and idOrChar.id or idOrChar
    return type(id) == "string" and (id == Delver.ID or id:sub(1, #Delver.PREFIX) == Delver.PREFIX)
end

-- The rolled id for the `i`th delver of a fight seeded `seed`.
function Delver.idFor(seed, i)
    local classes = roots()
    local races = require("models.adventurers").RACES
    local roll = Seed.mix(seed or 0, i or 1, 4337) % 1000000
    local class = classes[Seed.mix(roll, 1, 7907) % #classes + 1]
    local race = races[Seed.mix(roll, 2, 7907) % #races + 1]
    return Delver.PREFIX .. class .. "." .. race .. "." .. tostring(roll)
end

-- Character.defs' lazy resolver for `character_stray_delver@...`: the hire's body, posted.
function Delver.variant(defs, id)
    if type(id) ~= "string" or id:sub(1, #Delver.PREFIX) ~= Delver.PREFIX then return nil end
    local Hire = require("models.hire")
    local def = Hire.variant(defs, Hire.PREFIX .. id:sub(#Delver.PREFIX + 1))
    if not def then return nil end
    def.hire = nil
    def.delver = true
    def.archetype = "holdGround"
    return def
end

-- Swap every bare delver id in `allyIds` for a rolled one, and rewrite the objective fields that named
-- it. Returns the new ally list and a copied objective (the spec's own comes off an immutable blueprint).
function Delver.roll(allyIds, objective, seed)
    local rolled, out, first = {}, allyIds, nil
    for i, id in ipairs(allyIds or {}) do
        if id == Delver.ID then
            if out == allyIds then
                out = {}
                for j, v in ipairs(allyIds) do out[j] = v end
            end
            out[i] = Delver.idFor(seed, i)
            rolled[#rolled + 1] = out[i]
            first = first or out[i]
        end
    end
    if not first or not objective then return out, objective end
    local obj = {}
    for k, v in pairs(objective) do obj[k] = v end
    for _, field in ipairs({ "protect", "who", "captive" }) do
        if obj[field] == Delver.ID then obj[field] = first end
    end
    return out, obj
end

-- THE DELVERS STILL STANDING when a fight is decided, as rolled ids, in seat order (2026-10-23). Read
-- by states/battle.lua's win BEFORE the mercy revive stands the fallen back up, so a delver who died is
-- not counted as saved. A saved one asks to join (states/game.lua's offerDelver, Hire.joinDelver).
function Delver.survivors(combat)
    local out = {}
    for _, u in ipairs((combat and combat.units) or {}) do
        if u.side == "party" and u.alive and not u.summoned and u.char and Delver.isDelver(u.char)
            and u.char.id ~= Delver.ID then
            out[#out + 1] = u.char.id
        end
    end
    return out
end

return Delver
