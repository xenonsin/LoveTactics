-- THE BESTIARY: what the company has met, and what it is still missing off each thing it met.
--
-- This is the chase board, and it is a bestiary rather than a checklist on a shop rack because the
-- author's own reading settled it: *"Create a bestiary with redacted entries. Obtaining this drop
-- reveals an entry, but seeing the redacted signals to the player that there is more to be found."*
--
-- WHY A REDACTED ROW BEATS A COUNT. A tally -- `41 of 216 carried out` -- is a number you read once and
-- forget, and it cannot tell you where to go. A redacted row is a specific hole with a specific body
-- standing behind it, so the readout and the destination are the same object. That is the same move
-- Vendor.stock already makes with `lockReason = "undiscovered"`: a ware you have not found stands on
-- the rack named, silhouetted, with the depth it falls at where its price would go. One notation, and
-- this is its second surface.
--
-- TWO LEDGERS, AND THEY ARE DIFFERENT QUESTIONS:
--
--   MET     `player.met` -- have I fought this body. Stamped at the end of a won fight, per blueprint
--           id. A body never met has no entry at all: the bestiary lists what you have seen, not the
--           contents of data/characters.
--   FOUND   `player.found` -- have I carried this ITEM out (Player.recordFound). Already exists, and
--           is what the counter reads to deal a second copy. The bestiary reads it too, which is the
--           whole of the redaction: a listed body shows every entry on its `drops` list, each either
--           named or struck out.
--
-- So nothing new is remembered about items. A body's list is public once you have met the body; which
-- rows are legible is the ledger the shelf was already keeping.
--
-- IT NEVER SHOWS WHAT A BODY HAS NOT GOT. A creature carries no `drops` (docs/bestiary.md's split --
-- bodied chaff carry gear, creature chaff carry natural weapons), so its entry shows its kit and no
-- redactions, and that reads correctly: there is nothing behind a wolf to go back for.
--
-- Pure logic, headless-safe. No love.graphics at require time.

local Character = require("models.character")
local Item = require("models.item")
local Player = require("models.player")
local Spoils = require("models.spoils")

local Bestiary = {}

-- Stamp that this company has fought `charId`. Returns true the first time, so a caller can say so.
function Bestiary.markMet(player, charId)
    if not (player and charId) then return false end
    if not Character.defs[charId] then return false end
    player.met = player.met or {}
    if player.met[charId] then return false end
    player.met[charId] = true
    return true
end

function Bestiary.hasMet(player, charId)
    return (player and player.met and player.met[charId]) == true
end

-- Stamp every body in a beaten roster. Called at the victory seam beside Player.recordFound, and takes
-- the same shape the spoils roll does (`{ { char = ... }, ... }`) so the two read one list.
--
-- MET MEANS FOUGHT, NOT KILLED. A body that walked off, was polymorphed, or was still standing when the
-- objective completed has still been met -- the entry is a record of what the company has SEEN, and a
-- player who fought a thing and did not finish it has learned exactly as much about what it carries.
function Bestiary.recordMet(player, enemyUnits)
    local added = 0
    for _, unit in ipairs(enemyUnits or {}) do
        local char = unit and unit.char
        if char and char.id and Bestiary.markMet(player, char.id) then added = added + 1 end
    end
    return added
end

-- ---------------------------------------------------------------------------
-- Reading an entry
-- ---------------------------------------------------------------------------

-- What `charId` is known to drop, as rows the panel draws straight:
--   { id, name, depth, found }   -- `found` false means REDACTED: the row is drawn struck out and
--                                   unnamed, which is the signal that there is more here.
--
-- Ordered shallowest first, matching the order Descent.dropFor and tools/drop_assign.lua put a list in,
-- so the entry reads as a ladder and the next thing to go back for is the top unfound row.
function Bestiary.dropRows(player, charId)
    local def = Character.defs[charId]
    local rows = {}
    for _, itemId in ipairs((def or {}).drops or {}) do
        local item = Item.defs[itemId]
        if item then
            rows[#rows + 1] = {
                id = itemId,
                name = item.name or itemId,
                depth = Spoils.depthOf(item),
                found = Player.hasFound(player, itemId),
            }
        end
    end
    return rows
end

-- How much of a body's list the company has carried out: found, total. A body with no list answers
-- 0, 0 -- which the panel reads as "nothing to go back for" rather than as "nothing found yet".
function Bestiary.progress(player, charId)
    local found, total = 0, 0
    for _, row in ipairs(Bestiary.dropRows(player, charId)) do
        total = total + 1
        if row.found then found = found + 1 end
    end
    return found, total
end

-- Every body the company has met, as entries the panel lists. Sorted by name so the list is stable and
-- readable; a caller that wants them grouped by circle reads `class` off each row.
function Bestiary.entries(player)
    local out = {}
    for charId in pairs((player or {}).met or {}) do
        local def = Character.defs[charId]
        if def then
            local found, total = Bestiary.progress(player, charId)
            out[#out + 1] = {
                id = charId,
                name = def.name or charId,
                kind = def.kind,
                tier = def.tier or 2,
                class = def.class,
                sprite = def.sprite,
                found = found,
                total = total,
                complete = total > 0 and found == total,
            }
        end
    end
    table.sort(out, function(a, b)
        if a.name ~= b.name then return a.name < b.name end
        return a.id < b.id
    end)
    return out
end

-- The company's whole standing with the book: bodies met, and how many drop rows are still struck out
-- across all of them. The second number is the one that says there is more to be found -- which is the
-- job the rack's rejected item count was going to do, done on the surface that can point at it.
function Bestiary.standing(player)
    local met, found, total = 0, 0, 0
    for _, entry in ipairs(Bestiary.entries(player)) do
        met = met + 1
        found = found + entry.found
        total = total + entry.total
    end
    return met, found, total
end

return Bestiary
