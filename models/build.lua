-- A build: one player's team, and the tactics they wrote for it, frozen so somebody else can fight
-- it while its author is nowhere near the game.
--
-- Live PvP needs two people online at the same moment, which is the rarer half of the problem. A
-- build answers the common half. It is taken when its owner presses Play PvP and kept; from then on
-- anyone can be matched against it with nobody on the other end.
--
-- What makes that a fight rather than a target dummy is that the GAMBITS travel with the roster.
-- AI.rulesFor (models/ai.lua) already reads a player's authored `aiRules` ahead of the blueprint's
-- own tactics and the posture's, so a restored build fights the way its author taught it to -- their
-- opening, their retreat rule, their held potion -- without the AI needing to know it is being run
-- by proxy. That layering is why this module is mostly serialization and almost no behaviour.
--
-- The shape is deliberately the save file's, reused rather than reinvented (Save.snapshotCharacter):
-- a build IS a party, and the question "what of a character is worth writing down" has one answer in
-- this codebase, not two.
--
-- Pure data in and out -- no love.* -- so it loads headless and a build can be written, read, and
-- one day posted to a server without dragging the graphics stack behind it.

local Character = require("models.character")
local Item = require("models.item")
local Save = require("models.save")

local Build = {}

-- Bumped when the SHAPE changes in a way an older reader would misread. Unlike the save file, a
-- build travels between machines, so a version it does not recognise is refused rather than
-- salvaged: half-understanding somebody else's team means fighting a different one than they built.
Build.VERSION = 1

-- ---------------------------------------------------------------------------
-- Taking a build
-- ---------------------------------------------------------------------------

-- Freeze `party` (a list of live character instances -- normally player.party) as a build.
-- `meta` carries whatever the matchmaker wants to show on the card: { name, prestige }.
function Build.from(party, meta)
    meta = meta or {}
    local snap = {
        version = Build.VERSION,
        name = meta.name,
        prestige = meta.prestige,
        party = {},
    }
    for i, char in ipairs(party or {}) do
        snap.party[i] = Save.snapshotCharacter(char)
    end
    return snap
end

-- ---------------------------------------------------------------------------
-- Reading one back
-- ---------------------------------------------------------------------------

-- Every content id a build leans on, gathered so they can be checked before anything is built.
local function missingIds(snap)
    local missing = {}
    for _, charSnap in ipairs(snap.party or {}) do
        if not Save.known(Character.defs, charSnap.id) then
            missing[#missing + 1] = "character " .. tostring(charSnap.id)
        end
        for cell, itemSnap in pairs(charSnap.inventory or {}) do
            if not Save.known(Item.defs, itemSnap.id) then
                missing[#missing + 1] = "item " .. tostring(itemSnap.id)
                    .. " (" .. tostring(charSnap.id) .. " cell " .. tostring(cell) .. ")"
            end
        end
    end
    return missing
end

-- Rehydrate a build into live character instances. Returns the list, or nil plus a reason.
--
-- Unknown ids REFUSE the whole build rather than being dropped the way a save drops them (see
-- Save's `known`). A save is the player's own history and is worth salvaging in part; a build is
-- somebody else's team, and quietly leaving out the item their whole opening depended on does not
-- produce a slightly degraded opponent -- it produces a different one, presented as theirs. Better
-- to say the build cannot be read on this version than to lie about whose team it is.
function Build.restore(snap)
    if type(snap) ~= "table" then return nil, "not a build" end
    if snap.version ~= Build.VERSION then
        return nil, "build version " .. tostring(snap.version) .. " (this game reads "
            .. Build.VERSION .. ")"
    end
    if type(snap.party) ~= "table" or #snap.party == 0 then return nil, "build has no party" end

    local missing = missingIds(snap)
    if #missing > 0 then
        return nil, "unknown content: " .. table.concat(missing, ", ")
    end

    local chars = {}
    for i, charSnap in ipairs(snap.party) do
        chars[i] = Save.restoreCharacter(charSnap)
        -- The author's own auto-battle preference is theirs and means nothing here: it is only ever
        -- consulted for player-controlled units, and every unit in a restored build is run by the
        -- AI. Cleared so a build can never be read as asking for control it does not get.
        chars[i].autoBattle = nil
    end
    return chars
end

-- ---------------------------------------------------------------------------
-- Transport
-- ---------------------------------------------------------------------------

-- A build as a Lua source string, and back. The same encoder the save file uses: keys sorted (so two
-- builds diff and hash stably), and it ERRORS on a function or userdata rather than writing it -- the
-- property that makes a build safe to hand around, since an authored rule is scalars all the way
-- down (models/ai.lua) and anything that is not has no business travelling.
function Build.encode(snap)
    return "-- LoveTactics build. Generated file.\nreturn " .. Save.encode(snap, 0) .. "\n"
end

-- Decoding runs the chunk in an empty environment (see Save.decode), so a build that arrives from
-- somewhere else cannot reach a global on the way in. Returns nil on anything malformed.
function Build.decode(source)
    if type(source) ~= "string" then return nil end
    return Save.decode(source)
end

return Build
