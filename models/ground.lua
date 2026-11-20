-- What the company could not carry, left lying on the tile where it was found.
--
-- A FULL BAG USED TO EAT THE FIND. A fight's takings past the ceiling were "left behind" with a toast,
-- and a chest whose contents did not fit stayed shut. Both were the game deciding for the player that a
-- reward was not theirs. Now the surplus lands on the ground of the cell the company is standing on, is
-- drawn there as a mark, and is picked up again by walking back onto that cell with room in the pack.
--
-- PLAIN DATA ON THE CELL (`cell.ground`, a list of Save.snapshotItem records), so it rides the run
-- save and Descent.keepFloor with the rest of the board and needs no ledger of its own. It lives as long
-- as the floor does: a run that ends -- climbed out of or wiped -- walks new ground next time, and what
-- was left on the old ground is gone with it, which is the haul rule (Descent.wipe) applied to the finds
-- the company never carried in the first place.
--
-- Kept free of love.graphics so it loads under the headless suite.
local Ground = {}

local function Save() return require("models.save") end

-- Is anything lying here?
function Ground.has(cell)
    return cell ~= nil and cell.ground ~= nil and #cell.ground > 0
end

-- How many pieces (slots, not quantities) are lying here.
function Ground.count(cell)
    return (cell and cell.ground) and #cell.ground or 0
end

-- Put a live item instance down on `cell`. Returns true when it landed.
function Ground.drop(cell, item)
    if not (cell and item) then return false end
    cell.ground = cell.ground or {}
    cell.ground[#cell.ground + 1] = Save().snapshotItem(item)
    return true
end

-- Would `item` go into the bag without needing a slot of its own -- a stack that tops up existing stacks
-- in the pack completely?
local function absorbs(pack, item)
    local Item = require("models.item")
    if not Item.isStackable(item) then return false end
    local want = item.quantity or 1
    for _, existing in ipairs(pack or {}) do
        if existing.id == item.id and (existing.level or 0) == (item.level or 0)
            and Item.isStackable(existing) then
            want = want - math.max(0, Item.maxStack(existing) - (existing.quantity or 1))
            if want <= 0 then return true end
        end
    end
    return false
end

-- Does `item` fit in the company's bag right now? `room` is optional -- a function answering how many
-- free slots are left -- and defaults to Descent.carryRoom.
function Ground.fits(player, item, room)
    room = room or function() return require("models.descent").carryRoom(player) end
    if room() > 0 then return true end
    return absorbs(player and player.pack, item)
end

-- Pick up what fits. Every piece that fits goes through Player.stow (the one seam); what does not stays
-- on the cell, in the order it was dropped. Returns the list of items taken and the count left lying.
function Ground.pickUp(player, cell, room)
    if not Ground.has(cell) then return {}, 0 end
    local Player = require("models.player")
    local Item = require("models.item")
    local Material = require("models.material")
    local taken, kept = {}, {}
    for _, snap in ipairs(cell.ground) do
        -- A blueprint deleted since the floor was saved is simply gone, as it is from a stash on load.
        if Item.defs[snap.id] or Material.defs[snap.id] then
            local item = Save().restoreItem(snap)
            if item and Ground.fits(player, item, room) then
                Player.stow(player, item)
                taken[#taken + 1] = item
            else
                kept[#kept + 1] = snap
            end
        end
    end
    cell.ground = (#kept > 0) and kept or nil
    return taken, #kept
end

return Ground
