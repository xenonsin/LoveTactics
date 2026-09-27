-- THE GORGED: a vampire that drank until it filled the room (Wrath's vampires, reviewed 2026-09-26/27; an elite on
-- floor 8). Its three rules live here, so the organ that carries them (trait_full_to_bursting), the ground it spills
-- (hazard_blood_pool) and the spec all read one copy.
--
--   SPILL       each blow that wounds it and leaves it standing puts a blood pool on one free tile beside its body.
--               A pool never stacks: a tile already holding one is passed over, and a body ringed in pools spills
--               nothing new.
--   THE POOL    a VAMPIRE that steps into one drinks it dry: its Thirst resets and it heals (Thirst.feed, the one
--               door every drink comes through). A LIVING body that steps into one bleeds, and the wound is the
--               Gorged's own -- so a company that wades through its pools feeds it every step they take after
--               (Running Feeds It). The undead, the constructs and the rest walk through untouched.
--   THE BURST   at half health, once: every tile within 1 of its body floods, it shrinks to ONE tile, it moves
--               faster, and it is in Bloodlust for the rest of the fight -- no drink lifts it.
--
-- THE FOOTPRINT CHANGES IN PLACE. A body's size is `unit.w`/`unit.h`, read live by every occupancy, reach and
-- pathing question (Combat.unitAt, Combat.unitCells, Combat.cellGap), so shrinking it is two fields and the
-- blueprint's `footprint` on the runtime char -- no second blueprint and no swap. It keeps its anchor (the
-- top-left cell of the old block), its side, its health and its kit.
--
-- Pure logic, no love.graphics. Combat, Hazard and Status are required lazily: combat.lua reaches the trait that
-- calls this from inside its damage funnel.
local Gorged = {}

Gorged.POOL = "hazard_blood_pool"
Gorged.POOL_TURNS = 15          -- a pool lasts ~3 turns (Status.TICKS_PER_TURN = 5)
Gorged.DRINK_SHARE = 0.25       -- a pool is a drink of a quarter of the drinker's max health (it heals 30% of that)
Gorged.BURST_AT = 0.50          -- the burst, as a share of max health
Gorged.BURST_MOVE = 2           -- what the burst adds to its movement...
Gorged.BURST_SPEED = 2          -- ...and to its speed

-- Every walkable tile at Manhattan gap <= `r` from a box (x, y, w, h), and outside it when `outside` is set.
local function cellsAround(combat, x, y, w, h, r, outside)
    local Combat = require("models.combat")
    local tiles = combat and combat.arena and combat.arena.tiles
    local box = { x = x, y = y, w = w, h = h }
    local out = {}
    for ty = y - r, y + h - 1 + r do
        for tx = x - r, x + w - 1 + r do
            local cell = tiles and tiles[ty] and tiles[ty][tx]
            local gap = Combat.cellGap(tx, ty, box)
            if cell and cell.walkable and gap <= r and not (outside and gap == 0) then
                out[#out + 1] = { x = tx, y = ty }
            end
        end
    end
    return out
end

-- Lay one pool at (x, y), spilled by `gorged`. The spiller rides on the zone, so a wound the pool opens is its.
function Gorged.pool(combat, x, y, gorged)
    local Hazard = require("models.hazard")
    if Hazard.at(combat, x, y, Gorged.POOL) then return nil end -- a pool never stacks
    -- The spiller is stamped BEFORE placement's own entry fires, so a body the pool lands under bleeds to it.
    local stamp = combat._poolSpiller
    combat._poolSpiller = gorged
    local h = Hazard.place(combat, x, y, Gorged.POOL, { duration = Gorged.POOL_TURNS })
    combat._poolSpiller = stamp
    if h and not h.spiller then h.spiller = gorged end
    return h
end

-- SPILL: a pool on one tile beside `gorged`'s body with none on it, preferring an empty one (where a vampire can
-- step later) over one somebody stands on. Picked off the fight's own roll, so a seed reproduces it. Returns the
-- zone, or nil when every tile beside it already holds a pool (or none is walkable).
function Gorged.spill(combat, gorged)
    if not (combat and gorged and gorged.alive) then return nil end
    local Combat = require("models.combat")
    local Hazard = require("models.hazard")
    local free, held = {}, {}
    for _, c in ipairs(cellsAround(combat, gorged.x, gorged.y, gorged.w or 1, gorged.h or 1, 1, true)) do
        if not Hazard.at(combat, c.x, c.y, Gorged.POOL) and not Combat.objectAt(combat, c.x, c.y) then
            if Combat.unitAt(combat, c.x, c.y) then held[#held + 1] = c else free[#free + 1] = c end
        end
    end
    local pick = #free > 0 and free or held
    if #pick == 0 then return nil end
    local c = pick[Combat.roll(combat, #pick)]
    return Gorged.pool(combat, c.x, c.y, gorged)
end

-- What stepping into a pool does to `unit` (hazard_blood_pool's onEnter). A vampire drinks it dry; a living body
-- bleeds, the wound opened by whoever spilled it.
function Gorged.enter(combat, hazard, unit)
    if not (combat and unit and unit.alive) then return end
    local Thirst = require("models.thirst")
    if Thirst.isVampire(unit) then
        local hp = unit.char.stats.health
        local drink = math.max(1, math.floor((hp.max or 0) * Gorged.DRINK_SHARE + 0.5))
        Thirst.feed(combat, unit, drink)
        require("models.combat").logEvent(combat, "action",
            string.format("%s drinks from the pool.", (unit.char and unit.char.name) or "It"), unit)
        require("models.hazard").consume(combat, hazard)
        return
    end
    if not Thirst.isLiving(unit) then return end
    local spiller = hazard.spiller or combat._poolSpiller
    require("models.status").apply(combat, unit, "status_bleed",
        { applier = (spiller and spiller.alive) and spiller or nil })
end

-- THE BURST (trait_full_to_bursting's onDamaged, the blow that crosses half). Once. Returns true if it burst.
function Gorged.burst(combat, gorged)
    if not (combat and gorged and gorged.alive) or gorged._burst then return false end
    local Combat = require("models.combat")
    local Thirst = require("models.thirst")
    gorged._burst = true
    local ox, oy, ow, oh = gorged.x, gorged.y, gorged.w or 1, gorged.h or 1
    -- Shrink first, so the flood lands around a body that already stands on one tile.
    gorged.w, gorged.h = 1, 1
    gorged.char.footprint = { w = 1, h = 1 }
    Combat.logEvent(combat, "action",
        string.format("%s bursts.", (gorged.char and gorged.char.name) or "It"), gorged)
    -- Fast, and in Bloodlust for good: `bloodlustHolds` keeps Thirst.feed from lifting it.
    gorged.bonus = gorged.bonus or {}
    gorged.bonus.movement = (gorged.bonus.movement or 0) + Gorged.BURST_MOVE
    gorged.bonus.speed = (gorged.bonus.speed or 0) + Gorged.BURST_SPEED
    gorged.bloodlustHolds = true
    Thirst.enterBloodlust(combat, gorged)
    -- The flood: every tile within 1 of the body it WAS, less the one it now stands on (it is what burst).
    for _, c in ipairs(cellsAround(combat, ox, oy, ow, oh, 1, false)) do
        if not (c.x == gorged.x and c.y == gorged.y) then Gorged.pool(combat, c.x, c.y, gorged) end
    end
    return true
end

-- A Bloodlust that holds: re-entered at the close of each of its turns if something (a Cure) took it off.
function Gorged.holdBloodlust(combat, unit)
    if not (unit and unit.alive and unit.bloodlustHolds) then return end
    local Thirst = require("models.thirst")
    if not require("models.status").has(unit, Thirst.BLOODLUST) then Thirst.enterBloodlust(combat, unit) end
end

return Gorged
