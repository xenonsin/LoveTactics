-- THE MAW: Gluttony's stop for INSATIABLE and WASTEFULNESS (data/encounters/encounter_the_maw.lua). Reviewed
-- in three rounds on 2026-09-29; every rule here is one a line approved.
--
-- Feed it N pieces from the pack and it destroys them, then hands back ONE sealed find a rung above the best
-- of them. N starts at 1 and climbs by one every feeding, for the whole save, and it never closes: the only
-- thing that stops an appetite is the price. So it limits itself without an alarm or a cap -- by the fourth
-- feeding it costs a company's spare kit for one piece.
--
-- WHAT A "PIECE" IS: any read, unbound piece of gear or ability in the pack. Not a consumable -- a draught
-- is a supply rather than a piece, and a stack of twelve would otherwise pay a whole feeding by itself --
-- and not an unread husk, which Player.takeFromList refuses to move anyway.
--
-- WHAT "A RUNG ABOVE" READS: `unlockLevel`, the grade rank the shelf is cut on (docs/shelf.md), so "a rung
-- above the best piece fed" means one step up the same ladder the counters open on. The find is SEALED, as
-- every find off a stop is, so its forge level is still read at the Touchstone.
--
-- Pure: no love.graphics, so tests/maw_spec.lua runs it headless.
local Item = require("models.item")

local Maw = {}

-- The save's record, created on first ask. `fed` counts feedings ever made.
function Maw.state(player)
    if not player then return { fed = 0 } end
    player.gluttonyMaw = player.gluttonyMaw or { fed = 0 }
    return player.gluttonyMaw
end

-- How many pieces the next feeding costs.
function Maw.price(player)
    return (Maw.state(player).fed or 0) + 1
end

-- May `item` be fed to it?
function Maw.feedable(item)
    if type(item) ~= "table" then return false end
    if require("models.identify").isUnidentified(item) then return false end
    local def = Item.defs[item.id]
    if not def or def.type == "consumable" or def.bound then return false end
    return true
end

-- The pack's feedable pieces, as `{ index, item }` in pack order.
function Maw.candidates(player)
    local out = {}
    for i, item in ipairs((player and player.pack) or {}) do
        if Maw.feedable(item) then out[#out + 1] = { index = i, item = item } end
    end
    return out
end

-- A piece's rung: its grade rank.
function Maw.rungOf(item)
    local def = item and Item.defs[item.id]
    return (def and def.unlockLevel) or 0
end

-- The rung the find is drawn at: one above the best piece fed, never past the ladder's top.
function Maw.targetRung(items)
    local best = 0
    for _, item in ipairs(items or {}) do best = math.max(best, Maw.rungOf(item)) end
    return math.min(require("models.class").CLASS_LEVEL_CAP, best + 1)
end

-- Every sealable blueprint at exactly `rung`, sorted by id so a seed reproduces.
local function atRung(rung)
    local Identify = require("models.identify")
    local ids = {}
    for id, def in pairs(Item.defs) do
        if (def.unlockLevel or 0) == rung and Identify.canSeal(def) then ids[#ids + 1] = id end
    end
    table.sort(ids)
    return ids
end

-- The id it hands back for `items`, or nil when the whole ladder is empty. Drawn at the target rung; a rung
-- with nothing sealable on it looks UP first (the promise is "above", and a richer find keeps it), then down.
function Maw.pickReward(items, rnd)
    rnd = rnd or math.random
    local target = Maw.targetRung(items)
    local cap = require("models.class").CLASS_LEVEL_CAP
    local order = {}
    for r = target, cap do order[#order + 1] = r end
    for r = target - 1, 0, -1 do order[#order + 1] = r end
    for _, r in ipairs(order) do
        local ids = atRung(r)
        if #ids > 0 then
            local i = math.min(#ids, math.floor(rnd() * #ids) + 1)
            return ids[i]
        end
    end
    return nil
end

-- FEED IT. `indices` are pack positions the player picked; exactly Maw.price of them, each feedable. Removes
-- them, grants the sealed find into the pack (Identify.grant -> Player.stow), and counts the feeding.
-- Returns `{ id, floor }` for the reveal, or nil and a reason when the feeding is refused -- in which case
-- nothing has been taken.
function Maw.feed(player, indices, floorLevel, rnd)
    if not player then return nil, "no company" end
    local price = Maw.price(player)
    if #(indices or {}) ~= price then return nil, "it wants " .. price end
    local seen, items = {}, {}
    for _, i in ipairs(indices) do
        local item = (player.pack or {})[i]
        if seen[i] or not Maw.feedable(item) then return nil, "that cannot be fed" end
        seen[i] = true
        items[#items + 1] = item
    end
    local id = Maw.pickReward(items, rnd)
    if not id then return nil, "nothing to give back" end
    -- Highest index first, so each removal leaves the positions still to come where they were.
    local sorted = {}
    for _, i in ipairs(indices) do sorted[#sorted + 1] = i end
    table.sort(sorted, function(a, b) return a > b end)
    local Player = require("models.player")
    for _, i in ipairs(sorted) do Player.takeFromPack(player, i) end
    local floor = math.max(1, floorLevel or 1)
    require("models.identify").grant(player, id, floor)
    local s = Maw.state(player)
    s.fed = (s.fed or 0) + 1
    return { id = id, floor = floor }
end

return Maw
