-- SENDING FINDS UP: the two ways a company makes part of its haul safe before it climbs out.
--
-- THE BAG HAS NO BOTTOM AND THE WIPE TAKES ALL OF IT (2026-11-24). A company walks down with what is in
-- its grids and nothing else -- nothing is packed in town -- and everything it finds lands in the bag,
-- which holds any amount. Dying empties the bag. So the haul is a stake that grows with every floor, and
-- what this file sells is the only way to bank a piece of it without ending the run:
--
--   THE HOIST   a stop on every floor (`kind = "hoist"`, Descent.sendUpStops). It sends up to
--               SendUp.HOIST_LIMIT pieces from the bag to the town stash, ONCE: the stop is spent on use.
--   THE MULE    found once, on floor SendUp.MULE_FLOOR (`kind = "mule"`, Descent.muleStops), and the
--               company's for good after. A button on every floor's map then sends up to
--               SendUp.MULE_LIMIT pieces home, and the mule is away for SendUp.MULE_REST fights before
--               the button works again. It never fights.
--
-- BOTH ARE A SHORT LIST, NOT THE BAG. A send that could empty the bag would make the wipe cost nothing
-- for anybody willing to walk to the stop, so each send is a choice of a few pieces out of many.
-- `haulBonus` gear (Still Hungry) adds to both limits, best rather than sum (Descent.haulBonus).
--
-- A SENT PIECE IS NO LONGER A FIND. The wipe takes the trip's finds by diffing the company against the
-- entry snapshot (Player.atRisk), and that diff reads the stash as well as the bag. A piece moved to the
-- stash without telling the snapshot would still read as found and be taken anyway, so a send writes the
-- piece into `run.entry.stash` as it lands -- it is now something the company owns, like anything it
-- walked in with.
--
-- Pure model: no love.graphics, so it loads under the headless runner.

local SendUp = {}

SendUp.HOIST_LIMIT = 3 -- pieces one hoist sends up
SendUp.MULE_LIMIT = 2  -- pieces one trip of the mule sends up
SendUp.MULE_REST = 5   -- fights the mule is away after a trip

local function Player() return require("models.player") end
local function Descent() return require("models.descent") end

-- How many pieces a send from `source` ("hoist" | "mule") may carry.
function SendUp.limit(player, source)
    local base = (source == "mule") and SendUp.MULE_LIMIT or SendUp.HOIST_LIMIT
    return base + Descent().haulBonus(player)
end

-- What may go up: the bag's own contents. Bound pieces never move (Item.isBound), so they are left out.
function SendUp.candidates(player)
    local Item = require("models.item")
    local out = {}
    for _, item in ipairs((player and player.pack) or {}) do
        if not Item.isBound(item) then out[#out + 1] = item end
    end
    return out
end

-- Send `items` (live instances from the bag) up to the stash, at most `limit` of them. Returns the list
-- actually sent. A whole stack is one piece, as a stack is one slot everywhere else.
function SendUp.send(player, items, limit)
    local sent = {}
    if not (player and player.pack) then return sent end
    limit = limit or math.huge
    local run = player.descentRun
    local entry = run and run.entry
    for _, item in ipairs(items or {}) do
        if #sent >= limit then break end
        for i = #player.pack, 1, -1 do
            if player.pack[i] == item then
                table.remove(player.pack, i)
                -- ...AND IT IS THE COMPANY'S NOW: recorded on the snapshot the wipe measures against.
                if entry then
                    entry.stash = entry.stash or {}
                    entry.stash[#entry.stash + 1] = { id = item.id, level = item.level, quantity = item.quantity }
                end
                Player().addToStash(player, item)
                sent[#sent + 1] = item
                break
            end
        end
    end
    return sent
end

-- ---------------------------------------------------------------------------
-- The mule
-- ---------------------------------------------------------------------------

-- The floor the mule waits on until it is found (Descent.muleStops).
SendUp.MULE_FLOOR = 5

-- Has this company found the mule? A campaign fact, kept on the player and saved (`player.riftMule`).
function SendUp.muleUnlocked(player)
    return player ~= nil and player.riftMule == true
end

-- Found it: the button is on every floor from now on. Returns true the first time only.
function SendUp.unlockMule(player)
    if not player or player.riftMule then return false end
    player.riftMule = true
    return true
end

-- Fights left before the mule is back; 0 when it is here. Kept on the run, so the trip that ends takes
-- the count with it: a mule that went up is waiting at the Gate for the next descent.
function SendUp.muleAway(player)
    local run = player and player.descentRun
    return (run and run.muleRest) or 0
end

-- May the mule be sent right now? Underground, found, home, and something in the bag to send.
function SendUp.muleReady(player)
    if not Player().packOpen(player) then return false, "town" end
    if not SendUp.muleUnlocked(player) then return false, "none" end
    if SendUp.muleAway(player) > 0 then return false, "away" end
    if #SendUp.candidates(player) == 0 then return false, "empty" end
    return true
end

-- Send `items` up on the mule and start its rest. Returns the list sent; an empty choice spends nothing.
function SendUp.dispatchMule(player, items)
    local sent = SendUp.send(player, items, SendUp.limit(player, "mule"))
    if #sent > 0 and player.descentRun then player.descentRun.muleRest = SendUp.MULE_REST end
    return sent
end

-- One fight has been fought: the mule is a fight nearer home. Called on every fight the run clears.
function SendUp.tickMule(player)
    local run = player and player.descentRun
    if run and (run.muleRest or 0) > 0 then
        run.muleRest = run.muleRest - 1
        if run.muleRest <= 0 then run.muleRest = nil; return true end
    end
    return false
end

return SendUp
