-- THE BASIN: the Blood Countess's bath (Wrath's vampires, round 2/3, "The Blood Countess", approved 2026-09-27).
-- Bathory's bath, made a rule any visit can fall into rather than a story told once:
--
--   THE FILL        a 2x2 Blood Basin stands in the middle of the board (trait_blood_basin moves it there as the
--                   fight opens). EVERY point of Bleed damage taken anywhere, by anyone, on either side, runs into
--                   it (Combat.dealFlatDamage's `bleed` tag -> Basin.onBleed). The fill is a stacking status on
--                   the basin (status_basin_blood) whose badge prints the count, so the board says how close it is.
--   THE BATH        the moment it is full, every body on its side that bathes (trait_the_bath -- the Countess) is
--                   marked Bath Drawn (status_bath_drawn). At the TOP of her next turn she bathes, wherever she
--                   stands: healed to full, and Bathed (+2 Speed, +20% of her own Damage) for the rest of the fight.
--                   The basin empties and starts again.
--   REPEAT          Bathed stacks to TWO (Basin.MAX_BATHS). A third bath still heals her to full, but adds nothing.
--   THE ANSWERS     break the basin (it is an object with a health bar: a broken basin fills nothing and draws no
--                   bath, even one already marked), or stop bleeding -- Bleed bites per tile moved, so a company
--                   that holds still starves it. Her own blows shove two tiles and open the wound first, so she
--                   is the one making you move.
--
-- Pure logic, no love.graphics. Combat, Status and Trait are required lazily: combat.lua reaches this module from
-- inside its damage funnel.
local Basin = {}

Basin.FILL = "status_basin_blood"
Basin.DRAWN = "status_bath_drawn"
Basin.BATHED = "status_bathed"
Basin.CAPACITY = 45        -- Bleed points to fill it (the status's own `stacks` cap reads this)
Basin.MAX_BATHS = 2        -- Bathed stacks this high, and no higher
Basin.SPEED = 2            -- per bath
Basin.DAMAGE_SHARE = 0.20  -- per bath, of her own Damage

local function name(u) return (u and u.char and u.char.name) or "It" end

-- The live basins on the board (bodies carrying trait_blood_basin's `bloodBasin`).
function Basin.basins(combat)
    local Trait = require("models.trait")
    local out = {}
    for _, u in ipairs((combat and combat.units) or {}) do
        if u.alive and Trait.flag(u, "bloodBasin") then out[#out + 1] = u end
    end
    return out
end

-- How full `basin` is (its Blood stacks), and whether that is all the way.
function Basin.level(basin)
    return require("models.status").stacksOf(basin, Basin.FILL)
end

function Basin.isFull(basin)
    return basin ~= nil and basin.alive and Basin.level(basin) >= Basin.CAPACITY
end

-- The basin is full: mark every living bather on its side. The mark carries the basin, so breaking it before
-- her turn comes round calls the bath off.
function Basin.drawBath(combat, basin)
    local Status = require("models.status")
    local Trait = require("models.trait")
    for _, u in ipairs(combat.units or {}) do
        if u.alive and u.side == basin.side and Trait.flag(u, "bathes") and not Status.has(u, Basin.DRAWN) then
            local st = Status.apply(combat, u, Basin.DRAWN)
            if st then st.basin = basin end
        end
    end
    require("models.combat").logEvent(combat, "action", "The basin is full.", basin)
end

-- `amount` points of Bleed damage were just taken somewhere on the board (Combat.dealFlatDamage). Every basin
-- standing takes them in; one that tops out draws the bath.
function Basin.onBleed(combat, target, amount)
    if not (combat and (amount or 0) > 0) then return end
    local basins = Basin.basins(combat)
    if #basins == 0 then return end
    local Status = require("models.status")
    for _, basin in ipairs(basins) do
        local before = Basin.level(basin)
        if before < Basin.CAPACITY then
            Status.apply(combat, basin, Basin.FILL, { magnitude = math.min(amount, Basin.CAPACITY - before) })
            if Basin.isFull(basin) then Basin.drawBath(combat, basin) end
        end
    end
end

-- `unit` BATHES in `basin`: healed to full (a feeding heal, so the vampire tag's Grave-Cold lets it through),
-- one more stack of Bathed up to the cap, and the basin runs dry. Returns true when the bath was taken.
function Basin.bathe(combat, unit, basin)
    if not (combat and unit and unit.alive and Basin.isFull(basin)) then return false end
    local Combat = require("models.combat")
    local Status = require("models.status")
    local hp = unit.char and unit.char.stats and unit.char.stats.health
    if type(hp) == "table" and hp.max and hp.current < hp.max then
        Combat.applyHeal(combat, unit, hp.max - hp.current, { feeding = true })
    end
    local st = Status.get(unit, Basin.BATHED)
    local have = st and st.magnitude or 0
    local n = math.min(Basin.MAX_BATHS, have + 1)
    -- +20% of her OWN Damage per bath: read with this status's share taken back out, so a second bath is
    -- twenty percent of what she was, not of what the first bath made her.
    local own = Combat.flatStat(unit, "damage") - ((st and st.statBonus and st.statBonus.damage) or 0)
    local per = math.max(1, math.floor(own * Basin.DAMAGE_SHARE + 0.5))
    Status.apply(combat, unit, Basin.BATHED, {
        magnitude = n - have,
        statBonus = { speed = Basin.SPEED * n, damage = per * n },
    })
    Status.remove(combat, basin, Basin.FILL)
    Combat.logEvent(combat, "action", string.format("%s bathes in the blood.", name(unit)), unit)
    return true
end

-- The top of a bather's turn under Bath Drawn (status_bath_drawn's onTurnStart): take the bath if the basin
-- still stands full, and lift the mark either way.
function Basin.onTurnStart(combat, unit, status)
    local basin = status and status.basin
    Basin.bathe(combat, unit, basin)
    require("models.status").remove(combat, unit, Basin.DRAWN)
end

-- THE BASIN IS SET IN THE MIDDLE OF THE BOARD (trait_blood_basin's onCombatStart). The encounter seats it among
-- the enemy like any body; this lifts it to the free 2x2 block nearest the centre.
function Basin.center(combat, basin)
    local Combat = require("models.combat")
    local arena = combat and combat.arena
    if not (arena and arena.cols and arena.rows and basin and basin.alive) then return false end
    local w, h = basin.w or 1, basin.h or 1
    local cx = math.floor((arena.cols - w) / 2) + 1
    local cy = math.floor((arena.rows - h) / 2) + 1
    if basin.x == cx and basin.y == cy then return true end
    local x, y
    if Combat.footprintFree(combat, w, h, cx, cy, basin) then
        x, y = cx, cy
    else
        x, y = Combat.openBlockNear(combat, cx, cy, w, h, { ignore = basin, radius = 4 })
    end
    if not x then return false end
    basin.x, basin.y = x, y
    return true
end

-- A BASIN WITH NOBODY LEFT TO BATHE IN IT IS ONLY A TUB (the Dragon Egg's cold rule, trait_clutch). When the last
-- body on its side that takes turns has fallen, it goes with them, so a won fight does not end on a walk across
-- the board to break a tub.
function Basin.orphaned(combat, basin)
    for _, u in ipairs(combat.units or {}) do
        if u ~= basin and u.alive and u.side == basin.side and not u.timeless then return false end
    end
    return true
end

return Basin
