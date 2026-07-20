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
local Growth = require("models.growth")
local Save = require("models.save")

local Build = {}

-- ---------------------------------------------------------------------------
-- The fair fight
--
-- Every build is flattened to these before it takes the field, and so is the team facing it. This
-- is the ONLY fairness rule: there is no prestige bracket and no attempt to find a near-peer.
-- Matching by how far someone has climbed sounds fairer and is worse in practice -- it splits an
-- already small pool into slices, and the thinner the slice the longer you wait for a fight that
-- was never going to be closer than a normalized one. Everyone meets in the middle instead, so the
-- pool is everybody who has ever pressed the button.
--
-- What survives normalization is what the player actually decided: who they brought, what they gave
-- them, where it sits in the grid, and the gambits they wrote. What does not survive is how long
-- they have been playing.
--
-- Both numbers are tuning knobs, deliberately named rather than sprinkled.
-- ---------------------------------------------------------------------------

-- The level every duelist's characters are rebuilt at. Character level tracks prestige one-for-one
-- (Player.syncLevels), so this is "the prestige everyone fights at".
--
-- Set to the floor deliberately: a duel is decided by WHO you brought, what you gave them, where it
-- sits in the grid and the tactics you wrote -- not by how far up the curve either player has
-- climbed. Starting everyone at the bottom is the strongest possible statement of that, and it also
-- makes a duel legible, since both teams read at numbers a player already knows.
Build.NORMAL_LEVEL = 1

-- The ceiling an upgraded item is clamped to. Below it a weapon keeps the level its owner forged it
-- to -- bringing worse gear is a real choice and normalization should not quietly undo it. Items run
-- 0..Item.MAX_LEVEL (10), so this leaves the forge out of the argument almost entirely: gear is
-- WHICH items you chose and where you placed them, not how many materials you fed them.
Build.NORMAL_ITEM_LEVEL = 1

-- Bumped when the SHAPE changes in a way an older reader would misread. Unlike the save file, a
-- build travels between machines, so a version it does not recognise is refused rather than
-- salvaged: half-understanding somebody else's team means fighting a different one than they built.
Build.VERSION = 1

-- ---------------------------------------------------------------------------
-- Taking a build
-- ---------------------------------------------------------------------------

-- Freeze `party` (a list of live character instances -- normally player.party) as a build.
--
-- `meta.author` is who made it: { id, name }. The id has to be STABLE and comparable, because the
-- one thing matchmaking must never do is hand somebody their own team to fight -- a mirror of your
-- own tactics is not an opponent, it is a puzzle you already know the answer to. Locally that id
-- can be anything consistent; over Steam it wants to be the account id rather than a display name,
-- which is why it is a field of its own from version 1 instead of something to add later.
--
-- `meta.prestige` rides along for the card only. It is NOT a matchmaking filter -- see the
-- normalization block above for why the pool is deliberately unsliced.
function Build.from(party, meta)
    meta = meta or {}
    local author = meta.author or {}
    local snap = {
        version = Build.VERSION,
        author = { id = author.id, name = author.name },
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

-- One character, rebuilt at the duelling level rather than the one its author had reached.
--
-- Growth.resolve cannot run backward -- it is idempotent and never un-levels -- so a character is
-- not levelled DOWN, it is grown again from scratch: start at the blueprint, then climb to `level`
-- reading the class tally the author actually built up. That tally is the interesting part of how
-- someone played, and it survives; the number of levels they had time to accumulate does not.
--
-- This is also why normalization and determinism are the same mechanism. Growth is RNG-free (fixed
-- per-level gains per class), and dominantClass settles ties by name, so `(id, classUse, level)`
-- rebuilds the identical character on any machine -- which is what a duel needs from it anyway.
--
-- Item upgrade levels are clamped rather than stripped: gear below the ceiling keeps what its owner
-- forged, because bringing a lesser weapon is a decision and normalization should not silently
-- improve it.
local function normalized(charSnap, level, itemLevel)
    local snap = {}
    for k, v in pairs(charSnap) do snap[k] = v end

    -- Drop the author's level and their accumulated stat deltas: both are re-derived below from the
    -- tally. Keeping either would bake in the climb this is meant to erase.
    snap.level, snap.growth = nil, nil

    local inventory = {}
    for cell, itemSnap in pairs(charSnap.inventory or {}) do
        local lvl = itemSnap.level
        if lvl and lvl > itemLevel then lvl = itemLevel end
        inventory[cell] = { id = itemSnap.id, quantity = itemSnap.quantity, level = lvl }
    end
    snap.inventory = inventory

    local char = Save.restoreCharacter(snap)
    Growth.resolve(char, level)
    return char
end

-- Rehydrate a build into live character instances, normalized for a fair fight (see the block at the
-- top of this file). `opts.level` / `opts.itemLevel` override the defaults; there is deliberately no
-- way to ask for the team exactly as its author had it, because every caller here is about to put it
-- on a board against somebody.
--
-- Returns the list, or nil plus a reason.
--
-- Unknown ids REFUSE the whole build rather than being dropped the way a save drops them (see
-- Save's `known`). A save is the player's own history and is worth salvaging in part; a build is
-- somebody else's team, and quietly leaving out the item their whole opening depended on does not
-- produce a slightly degraded opponent -- it produces a different one, presented as theirs. Better
-- to say the build cannot be read on this version than to lie about whose team it is.
function Build.restore(snap, opts)
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

    local level = (opts and opts.level) or Build.NORMAL_LEVEL
    local itemLevel = (opts and opts.itemLevel) or Build.NORMAL_ITEM_LEVEL

    local chars = {}
    for i, charSnap in ipairs(snap.party) do
        chars[i] = normalized(charSnap, level, itemLevel)
        -- The author's own auto-battle preference is theirs and means nothing here: it is only ever
        -- consulted for player-controlled units, and every unit in a restored build is run by the
        -- AI. Cleared so a build can never be read as asking for control it does not get.
        chars[i].autoBattle = nil
    end
    return chars
end

-- Flatten `party` (live instances -- the local player's own team) the same way a restored build is,
-- so both sides of a duel meet on the same terms. Goes through a snapshot on purpose: normalizing
-- means rebuilding from the blueprint, and the snapshot is already the description of a character
-- that a rebuild reads.
function Build.normalizeParty(party, opts)
    local level = (opts and opts.level) or Build.NORMAL_LEVEL
    local itemLevel = (opts and opts.itemLevel) or Build.NORMAL_ITEM_LEVEL
    local out = {}
    for i, char in ipairs(party or {}) do
        out[i] = normalized(Save.snapshotCharacter(char), level, itemLevel)
    end
    return out
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
