-- THE COIN-EATERS (Greed's floor-5 beetles, reviewed 2026-09-25 -- "The Coin-Eaters" artifact): the two
-- things more than one blueprint needs, kept in one place so they cannot drift.
--
--   Scarab.hatch   a clutch opening into Gilded Scarabs. The Brood Queen's egg in the hoard
--                  (character_scarab_egg, status_scarab_hatch) and the company's Brood Sting
--                  (status_brood_sting) both end here, so an egg laid by either side hatches the same.
--   Scarab.roll    a coin heap pushed down a lane (ability_roll_heap). It merges every heap it rolls
--                  over, stops against the first body -- hurting it by how much gold it carries -- and a
--                  heap rolled into a HOARDER (trait_the_nest) is taken into her hoard instead.
--
-- Pure logic, headless-safe. Combat is reached lazily: item blueprints require this file while
-- models/combat.lua is still being required.

local Scarab = {}

Scarab.SCARAB = "character_gilded_scarab"
Scarab.HEAP = "hazard_coin_heap"
Scarab.HEAP_GOLD = 10     -- a heap with no authored amount (hazard_coin_heap's own HEAP_GOLD)
Scarab.ROLL_REACH = 4     -- how far a heap travels before it stops on its own
Scarab.ROLL_SHARE = 0.6   -- the blow a heap lands, as a share of the roller's Damage, per heap of gold in it

-- Hatch `n` scarabs on the free tiles nearest (x, y), for `side`, grown to `level`. `summoner` sustains
-- them where one is given (a party's Brood Sting: the scarabs leave with the one who laid them); nil
-- leaves them ordinary bodies. Returns the list hatched.
function Scarab.hatch(combat, x, y, side, n, level, summoner)
    local Combat = require("models.combat")
    local Character = require("models.character")
    local Growth = require("models.growth")
    local out = {}
    for _ = 1, n or 2 do
        local tx, ty = Combat.openTileNear(combat, x, y)
        if not tx then break end
        local char = Character.instantiate(Scarab.SCARAB)
        if level and level > 1 then Growth.resolve(char, level) end
        local opts = nil
        if summoner and summoner.alive then opts = { summoned = true, summoner = summoner } end
        out[#out + 1] = Combat.addUnit(combat, char, side, tx, ty, opts)
    end
    if #out > 0 then
        Combat.logEvent(combat, "action", string.format("The egg splits, and %d scarab%s crawl%s out.",
            #out, #out == 1 and "" or "s", #out == 1 and "s" or ""), out[1])
    end
    return out
end

-- The coin heap on (x, y), or nil. Read through `fx.hazardsAt` so a dry run answers it truthfully.
function Scarab.heapAt(fx, x, y)
    for _, h in ipairs(fx.hazardsAt(x, y) or {}) do
        if h.id == Scarab.HEAP and h.alive then return h end
    end
    return nil
end

local function cardinal(ax, ay, bx, by)
    local dx, dy = bx - ax, by - ay
    if math.abs(dx) >= math.abs(dy) then
        if dx == 0 then return 0, 0 end
        return (dx > 0) and 1 or -1, 0
    end
    return 0, (dy > 0) and 1 or -1
end

local function open(combat, x, y)
    local row = combat and combat.arena and combat.arena.tiles and combat.arena.tiles[y]
    local cell = row and row[x]
    if not (cell and cell.walkable) then return false end
    local Combat = require("models.combat")
    return not Combat.objectBlocksAt(combat, x, y)
end

-- Roll the heap on (hx, hy) away from `fx.user`, down the lane it lines up on -- or down (dx, dy) when
-- the caller names a direction (Carry Home, which rolls it toward the Queen). Every verb is an fx verb,
-- so the forecast reads the blow and the hoarding without moving a coin (placeHazard and consumeHazard
-- are inert in a dry run). Returns true when there was a heap to roll.
function Scarab.roll(fx, hx, hy, dx, dy, reach)
    local heap = Scarab.heapAt(fx, hx, hy)
    if not heap then return false end
    local user = fx.user
    if not dx then dx, dy = cardinal(user.x, user.y, hx, hy) end
    if dx == 0 and dy == 0 then return false end
    local combat = fx.combat
    local gold = heap.amount or Scarab.HEAP_GOLD
    local x, y = hx, hy
    fx.consumeHazard(heap)
    for _ = 1, reach or Scarab.ROLL_REACH do
        local nx, ny = x + dx, y + dy
        if not open(combat, nx, ny) then break end
        local body = fx.unitAt(nx, ny)
        if body then
            local Trait = require("models.trait")
            if body.side == user.side and Trait.flag(body, "hoardsHeaps") then
                -- Into her hoard: the gold is hers, and the heap is gone from the floor.
                fx.applyStatus(body, "status_hoard", { magnitude = gold })
                return true
            end
            if body.side ~= user.side then
                local stat = (user.char and user.char.stats and user.char.stats.damage) or 0
                if type(stat) == "table" then stat = stat.current or stat.max or 0 end
                local heaps = gold / Scarab.HEAP_GOLD
                fx.flatDamage(body, math.max(1, math.floor(stat * Scarab.ROLL_SHARE * heaps + 0.5)), { "impact" })
            end
            break
        end
        x, y = nx, ny
        local more = Scarab.heapAt(fx, x, y)
        if more then
            gold = gold + (more.amount or Scarab.HEAP_GOLD)
            fx.consumeHazard(more)
        end
    end
    -- A heap that comes to rest BESIDE a hoarder on the roller's side is hers as well: the colony carries
    -- the last step. Without it a heap had to arrive dead in line with her to count, and on a board the
    -- carrying almost never managed that.
    for _, u in ipairs(fx.unitsNear(x, y, 1) or {}) do
        local Trait = require("models.trait")
        if u.side == user.side and u.alive and Trait.flag(u, "hoardsHeaps") then
            fx.applyStatus(u, "status_hoard", { magnitude = gold })
            return true
        end
    end
    fx.placeHazard(x, y, Scarab.HEAP, { amount = gold })
    return true
end

-- Every live heap's cell, for an ability's `aiAims` (models/ai.lua): the planner offers a cast only the
-- tiles bodies stand on unless it is told where the floor is worth aiming at. `bare` leaves out a heap
-- somebody is standing on (an egg needs the tile).
function Scarab.heapCells(combat, bare)
    local Combat = require("models.combat")
    local out = {}
    for _, h in ipairs((combat and combat.hazards) or {}) do
        if h.alive and h.id == Scarab.HEAP and not (bare and Combat.unitAt(combat, h.x, h.y)) then
            out[#out + 1] = { x = h.x, y = h.y }
        end
    end
    return out
end

-- The living hoarder on `side` nearest (x, y) -- the Brood Queen a scarab carries home to -- or nil.
function Scarab.hoarderFor(combat, side, x, y)
    local Trait = require("models.trait")
    local best, bestD
    for _, u in ipairs((combat and combat.units) or {}) do
        if u.alive and u.side == side and Trait.flag(u, "hoardsHeaps") then
            local d = math.abs(u.x - x) + math.abs(u.y - y)
            if not bestD or d < bestD then best, bestD = u, d end
        end
    end
    return best
end

-- The way from (x, y) toward `to`, and how far to roll: straight in when the heap already lines up with
-- her, and otherwise ACROSS, along the shorter offset and only as far as it takes to line up -- so the next
-- carry rolls it home rather than past her.
function Scarab.toward(x, y, to)
    local ox, oy = to.x - x, to.y - y
    if ox == 0 or oy == 0 then
        local dx, dy = cardinal(x, y, to.x, to.y)
        return dx, dy, nil
    end
    if math.abs(ox) <= math.abs(oy) then return (ox > 0) and 1 or -1, 0, math.abs(ox) end
    return 0, (oy > 0) and 1 or -1, math.abs(oy)
end

return Scarab
