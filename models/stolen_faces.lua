-- STOLEN FACES: the machinery Envy's first Faceless line shares (reviewed 2026-10-01..03, "Envy's Bestiary",
-- round 2). The race (models/faces.lua) wears faces out of a dealt hand; the bodies of this line TAKE them --
-- off the foes they kill, off the body they flay, off the rift's champions -- and three of their drops lend the
-- trick to a person.
--
--   A FACE FOR EVERY KILL  the Faceless Assassin. Its hand is the faces of what it has killed. It enters in a
--                          common face and is locked in it until it strikes; the first blow out of any face is
--                          a critical (Combat.forcesCrit); a company body it downs is copied and worn at once,
--                          and THE SAVE REMEMBERS -- a companion it downed is in its hand on the next trip.
--   THE FLAYING            the Skin-Thief. Its hit Halts one of the company for 2 turns and the thief wears that
--                          body's face for the same 2 turns (status_stolen_face); the face goes back when the
--                          time ends or the thief dies.
--   THE RIFT'S CHAMPIONS   the Faceless Champion. Its hand is the rift's champions, and each face it puts on
--                          opens the way it would have at the bell (its race's opener runs as it is worn).
--
-- ONE STATUS FOR EVERY BORROWED BODY: status_stolen_face is the timer that owns a face worn for a while -- the
-- Skin-Thief's, Borrowed Face's, Hall of Faces'. Its onExpire is the single way back, on every removal path.
--
-- Pure logic (no love.graphics), so it loads under the headless tests.

local StolenFaces = {}

StolenFaces.STATUS = "status_stolen_face"
StolenFaces.TURN = 5 -- Status.TICKS_PER_TURN, stated here so this file requires nothing at load time

-- Who the Faceless Champion may wear: the rift's champions, as the review named them. Read through
-- Faces.isEligible, so a champion that is not a face (the Vampire Duelist is human-raced: humans are off the
-- rift's rolls, and a companion's own blueprint must never sit in a stranger's hand) simply is not dealt.
StolenFaces.CHAMPIONS = {
    "character_elf_bladedancer",
    "character_orc_pit_fighter",
    "character_oni_swordmaster",
    "character_vampire_duelist",
    "character_asura_adept",
}

-- The Assassin's disguise when nothing else on its side is a face worth borrowing: the circle's common
-- glass-things, as the review put it.
StolenFaces.DISGUISES = { "character_glass_mote", "character_glass_eater" }

function StolenFaces.champions()
    local Faces = require("models.faces")
    local out = {}
    for _, id in ipairs(StolenFaces.CHAMPIONS) do
        if Faces.isEligible(id) then out[#out + 1] = id end
    end
    return out
end

-- A FACE TAKEN OFF A BODY: a copy of the body underneath whatever it is wearing (Summon.copyChar), with the
-- few labels the copy builder leaves behind and a face's readers ask (its race, level and opening weapon).
function StolenFaces.copyOf(unitOrChar)
    local Faces = require("models.faces")
    local src = unitOrChar and unitOrChar.char and Faces.originalChar(unitOrChar) or unitOrChar
    if not (src and src.stats) then return nil end
    local copy = require("models.summon").copyChar(src)
    copy.race, copy.level, copy.kind, copy.tier = src.race, src.level, src.kind, src.tier
    copy.defaultAction, copy.defaultActionSlot = src.defaultAction, src.defaultActionSlot
    return copy
end

-- ---------------------------------------------------------------------------------------------------------
-- A face worn for a while (status_stolen_face)
-- ---------------------------------------------------------------------------------------------------------

local function isFaceless(unit)
    return unit.faceHand ~= nil or require("models.status").has(unit, "status_faceless")
end

-- `unit` wears `face` (a built char) for `ticks`, as a FIGHT does it -- the Skin-Thief's flaying. A Faceless
-- takes off whatever it wore and carries its organs in (Faces.wear), and is held in the face (faceLocked) so
-- its own read does not swap it out early. Refuses a body already wearing a stolen face. Returns the status.
function StolenFaces.wearFor(combat, unit, face, ticks, victim)
    if not (combat and unit and unit.alive and face) then return nil end
    local Status = require("models.status")
    local Transform = require("models.transform")
    if Status.has(unit, StolenFaces.STATUS) then return nil end
    local shape
    if isFaceless(unit) then
        shape = require("models.faces").wear(combat, unit, face)
    elseif not Transform.isTransformed(unit) then
        shape = Transform.apply(combat, unit, nil, { char = face })
    end
    if not shape then return nil end
    local wasLocked = unit.faceLocked
    unit.faceLocked = true
    local st = Status.apply(combat, unit, StolenFaces.STATUS, { duration = ticks, applier = unit })
    if not st then
        unit.faceLocked = wasLocked
        Transform.revert(combat, unit)
        return nil
    end
    st.victim, st.wasLocked = victim, wasLocked
    return st
end

-- The face comes off (status_stolen_face's onExpire, on every removal path): the body is its own again, the
-- read is its own again, and a body it flayed gets its face back -- its Halt lifts, if it is still the one the
-- flaying laid.
function StolenFaces.takeOff(combat, unit, st)
    if not unit then return end
    local Status = require("models.status")
    unit.faceLocked = st and st.wasLocked or nil
    require("models.transform").revert(combat, unit)
    local victim = st and st.victim
    if victim and victim.alive then
        local halt = Status.get(victim, "status_halted")
        if halt and halt.opener == unit then Status.remove(combat, victim, "status_halted") end
    end
end

-- ---------------------------------------------------------------------------------------------------------
-- The faces a body has killed (Borrowed Face, Hall of Faces -- trait_faces_of_the_slain)
-- ---------------------------------------------------------------------------------------------------------

-- `unit` killed `fallen`: bank its face, once per body however many carried items heard the death.
function StolenFaces.noteKill(unit, fallen)
    if not (unit and fallen and fallen.char) then return end
    unit.slainFaces = unit.slainFaces or {}
    for _, f in ipairs(unit.slainFaces) do
        if f.from == fallen then return end
    end
    local copy = StolenFaces.copyOf(fallen)
    if copy then unit.slainFaces[#unit.slainFaces + 1] = { from = fallen, char = copy } end
end

-- The last foe `unit` killed, as a face to wear (Borrowed Face), or nil.
function StolenFaces.lastSlain(unit)
    local list = unit and unit.slainFaces
    local last = list and list[#list]
    return last and last.char or nil
end

-- How many faces Hall of Faces still holds, and the newest unspent one (and its index).
function StolenFaces.hallCount(unit)
    local n = 0
    local spent = (unit and unit.hallSpent) or {}
    for i = 1, #((unit and unit.slainFaces) or {}) do
        if not spent[i] then n = n + 1 end
    end
    return n
end

function StolenFaces.hallNewest(unit)
    local list = (unit and unit.slainFaces) or {}
    local spent = (unit and unit.hallSpent) or {}
    for i = #list, 1, -1 do
        if not spent[i] then return list[i].char, i end
    end
    return nil
end

-- ---------------------------------------------------------------------------------------------------------
-- The Assassin: a face for every kill, and the save that remembers
-- ---------------------------------------------------------------------------------------------------------

local function activePlayer()
    local ok, Player = pcall(require, "models.player")
    return ok and Player.active or nil
end

local function rosterChar(player, charId)
    for _, char in ipairs((player and player.roster) or {}) do
        if char.id == charId then return char end
    end
    return nil
end

-- THE SAVE REMEMBERS (`player.facesTaken`, models/save.lua): keyed by the keeper's blueprint id, the roster ids
-- of the companions it has downed. Only a body on the live company's roster is written, so an escort, a
-- charmed foe or a fixture's stand-in never reaches the save.
function StolenFaces.remember(keeperId, char)
    local p = activePlayer()
    if not (p and keeperId and char and char.id and rosterChar(p, char.id)) then return false end
    p.facesTaken = p.facesTaken or {}
    local list = p.facesTaken[keeperId] or {}
    for _, id in ipairs(list) do
        if id == char.id then return false end
    end
    list[#list + 1] = char.id
    p.facesTaken[keeperId] = list
    return true
end

-- The faces `keeperId` remembers, as copies of the companions AS THEY ARE NOW (kit included) -- a companion
-- who has left the roster is not in the hand.
function StolenFaces.remembered(keeperId)
    local p = activePlayer()
    local out = {}
    for _, id in ipairs((p and p.facesTaken and p.facesTaken[keeperId]) or {}) do
        local char = rosterChar(p, id)
        local copy = char and StolenFaces.copyOf(char)
        if copy then out[#out + 1] = copy end
    end
    return out
end

-- The common face it walks in wearing: the first eligible body of its own side that is not Faceless, else one
-- of the circle's glass-things.
function StolenFaces.disguiseFor(combat, unit)
    local Faces = require("models.faces")
    for _, other in ipairs(combat.units or {}) do
        local id = other ~= unit and other.alive and other.side == unit.side and other.char
            and Faces.originalChar(other).id
        if id and Faces.isEligible(id) then return id end
    end
    for _, id in ipairs(StolenFaces.DISGUISES) do
        if Faces.isEligible(id) then return id end
    end
    return Faces.eligible()[1]
end

-- ---------------------------------------------------------------------------------------------------------
-- The Champion: a face opens the way it would have at the bell
-- ---------------------------------------------------------------------------------------------------------

-- `unit` has just put on a face. Whatever the LAST face's opener laid comes off with it, and the new face's
-- race opener runs (the Bladedancer is Unblemished again when it is worn again; nothing else carries over).
function StolenFaces.openFace(combat, unit)
    local Status = require("models.status")
    local Trait = require("models.trait")
    for _, id in ipairs(unit.faceOpened or {}) do Status.remove(combat, unit, id) end
    unit.faceOpened = nil
    local grants = {}
    for _, id in ipairs(require("models.race").grantsOf(unit.char and unit.char.race)) do grants[id] = true end
    if not next(grants) then return end
    local before = {}
    for _, st in ipairs(unit.statuses or {}) do before[st.id] = true end
    Trait.fire(combat, unit, "onCombatStart", {}, function(t) return t.item and grants[t.item.id] end)
    local opened = {}
    for _, st in ipairs(unit.statuses or {}) do
        if not before[st.id] then opened[#opened + 1] = st.id end
    end
    unit.faceOpened = opened
end

-- ---------------------------------------------------------------------------------------------------------
-- Mask of Champions: three reflexes, one worn at a time
-- ---------------------------------------------------------------------------------------------------------

StolenFaces.REFLEXES = { "status_untouchable", "status_the_challenge", "status_answers_every_blow" }

-- Which reflex `unit` wears now (its index in REFLEXES), or nil.
function StolenFaces.reflexWorn(unit)
    local Status = require("models.status")
    for i, id in ipairs(StolenFaces.REFLEXES) do
        if Status.has(unit, id) then return i end
    end
    return nil
end

-- The reflex a swap puts on: the next in order, skipping Untouchable once it has been marred.
function StolenFaces.nextReflex(unit)
    local i = StolenFaces.reflexWorn(unit) or 0
    for _ = 1, #StolenFaces.REFLEXES do
        i = i % #StolenFaces.REFLEXES + 1
        if not (i == 1 and unit.untouchableMarred) then return StolenFaces.REFLEXES[i] end
    end
    return StolenFaces.REFLEXES[2]
end

-- THE CHALLENGE, worn by a person: the foe with the most health is the challenger, named again each turn the
-- bearer ends (the Pit-Fighter's rule turned round to face the other side).
function StolenFaces.nameChallenger(combat, unit)
    local Status = require("models.status")
    local Combat = require("models.combat")
    local st = Status.get(unit, "status_the_challenge")
    if not st then return nil end
    local best
    for _, other in ipairs(combat.units or {}) do
        if other.alive and other.side ~= unit.side and not Combat.isOffTile(other) and not other.summoner then
            if not best or other.char.stats.health.current > best.char.stats.health.current then best = other end
        end
    end
    -- No Challenger badge on the foe: that one reads "named by the Pit-Fighter". The bearer's own badge (the
    -- Challenge) is the readout.
    st.exempt = best
    return best
end

return StolenFaces
