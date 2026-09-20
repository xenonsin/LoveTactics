-- THE COMMON BURDEN's rule: the line hardens for every hex ANYBODY in it is carrying
-- (data/items/utility/utility_common_burden.lua, docs/curses.md).
--
-- THE ONE COUNTING ITEM THAT READS THE COMPANY, where every other reads one grid. That makes a cursed
-- PARTY a build rather than one martyr: four bodies carrying one hex apiece pay this exactly as well as
-- one body carrying four, and the four-body version is far easier to survive.
--
-- WHICH IS WHY THE NUMBERS ARE SMALL. The pool it reads from is four times larger than a single grid's,
-- so a point apiece here is worth roughly what two apiece is worth on The Gathered Weight. Both armours
-- rather than damage, so the two charms are not competing to do the same job in the same cell.
--
-- COUNTED OFF THE BOARD, not off the player. `combat.units` is the company that actually walked into
-- this fight, which is the honest set -- a hexed body left in town is not sharing anything with anyone.
-- It also means the figure FALLS when an ally drops, which is the correct and slightly cruel reading:
-- the burden is common, and there are fewer of you to carry it.
return {
    name = "Common Burden",
    description = "Hardens the whole line for every hex the company is carrying.",
    per = 1,
    live = function(ctx)
        local unit, combat = ctx.unit, ctx.combat
        if not (unit and combat) then return nil end
        local Curse = require("models.curse")
        local n = 0
        for _, other in ipairs(combat.units or {}) do
            if other.alive and other.side == unit.side and other.char then
                n = n + Curse.countOn(other.char)
            end
        end
        if n <= 0 then return nil end
        local per = ctx.def.per or 1
        return { defense = per * n, magicDefense = per * n }
    end,
}
