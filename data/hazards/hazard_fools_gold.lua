-- FOOL'S GOLD: a false coin heap, laid by the trapper's piece of that name (data/items/ability/
-- ability_fools_gold.lua). The first FOE of whoever laid it to step on it catches Gold Fever -- driven at
-- the body on the layer's side standing nearest the heap, never the layer (`hazard.layer`) -- and the
-- heap is spent. A body on the layer's own side walks over it.
--
-- It WELCOMES a heap-seeker the way a real heap does (hazard_coin_heap.lua), so a dwarf's planner reads
-- it as gold and goes for it. It pays nobody anything: it is lead.
local function seeks(unit)
    local Trait = require("models.trait")
    return unit ~= nil and Trait.flag(unit, "seeksHeaps") ~= nil
end

return {
    name = "Fool's Gold",
    description = "A false coin heap. The first foe to step on it catches Gold Fever toward the nearest body on the other side.",
    tags = { "earth" },
    duration = 30,
    disposition = "neutral",
    welcomes = function(unit) return seeks(unit) end,
    onEnter = function(ctx)
        local unit, combat, heap = ctx.unit, ctx.combat, ctx.hazard
        if not (unit and unit.alive and combat) or ctx.isAlly(unit) then return end
        local Combat = require("models.combat")
        local bait, best
        for _, u in ipairs(combat.units or {}) do
            if u.alive and u ~= heap.layer and u.side == heap.side then
                local d = Combat.cellGap(heap.x, heap.y, u)
                if not best or d < best then bait, best = u, d end
            end
        end
        bait = bait or heap.layer
        ctx.consume()
        if not (bait and bait.alive) then return end
        require("models.status").apply(combat, unit, "status_gold_fever", { applier = bait })
        Combat.logEvent(combat, "action", string.format("%s snatches at the gold, and it is lead.",
            (unit.char and unit.char.name) or "It"), unit)
    end,
}
