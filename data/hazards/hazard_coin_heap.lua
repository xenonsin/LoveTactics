-- COIN HEAP: the Countinghouse Keep's signature ground (data/biomes/castle.lua), and the thing every
-- dwarf fight is about. Reviewed over three rounds, 2026-09-24 ("The Dwarves of Greed"): the dwarves do
-- not GUARD a heap, they go and get it -- Keno's note on the denied "Hoard" row, "they seek out the heaps
-- not defend it".
--
-- WHO STEPS ON IT DECIDES WHAT IT IS:
--   * A DWARF (anything carrying `seeksHeaps`, data/traits/trait_stout.lua) pockets it: the gold goes
--     into its coffer and it takes a stack of DRAGON-SICKNESS (+2 Damage, -1 Defense, no cap --
--     data/status/status_dragon_sickness.lua; round 2's note, "have heaps collected give them a buff
--     that stacks"). It hasted the pocketer in the first cut; round 2 cut that ("heap stacks should not
--     haste"). The coffer and the sickness both ride Inheritance to the next dwarf, and the gold spills
--     as bounty with the last, so a heap a dwarf took is not lost to the company, only moved.
--   * THE COMPANY loots it: the gold is the company's on a win (Combat.bounty), and EVERY dwarf on the
--     board catches GOLD FEVER (data/status/status_gold_fever.lua) -- Smaug knew the moment one cup was
--     gone (round 3). Driven at the looter, hitting harder and guarding worse: the player's lever is
--     taking a heap to pull the whole line off its plan, and choosing who eats the charge.
--   * Anybody else walks over it. A heap is not a slime's business.
--
-- `welcomes` is what makes the dwarves go for it without an authored rule: Hazard.tileBias reads a zone
-- that welcomes a body as friendly ground to that body's planner, so a dwarf scoring where to stand
-- prefers the heap, and models/ai.lua's fallback walk heads for the nearest one when there is nothing to
-- hit. Neutral to everyone else, so the company's own planner-driven bodies neither avoid nor seek it.
--
-- Lasts the fight (a heap is not weather). `amount` on the instance is the gold; HEAP_GOLD is the
-- floor's own heap.
local HEAP_GOLD = 10

local function seeks(unit)
    local Trait = require("models.trait")
    return unit ~= nil and Trait.flag(unit, "seeksHeaps") ~= nil
end

-- A GOLD GOLEM EATS a heap rather than pocketing it (trait_eats_heaps, "The Golems of Greed", 2026-09-25):
-- it heals and puts the gold back on as a plate (models/golem.lua, Golem.eat).
local function eats(unit)
    local Trait = require("models.trait")
    return unit ~= nil and Trait.flag(unit, "eatsHeaps") ~= nil
end

return {
    name = "Coin Heap",
    description = "Loose gold. A dwarf that pockets it takes Dragon-Sickness; the company that loots it banks the gold, and every dwarf on the board catches Gold Fever.",
    tags = { "earth" },
    duration = math.huge,
    disposition = "neutral",
    welcomes = function(unit) return (seeks(unit) or eats(unit)) and unit.side ~= "party" end,
    onEnter = function(ctx)
        local unit, combat = ctx.unit, ctx.combat
        if not (unit and unit.alive and combat) then return end
        local gold = ctx.amount or HEAP_GOLD
        local Combat = require("models.combat")
        local Status = require("models.status")
        local name = (unit.char and unit.char.name) or "Unit"
        -- A GILT PLATE knocked off its wearer (trait_shed_plate, "reclaim"): the wearer walking back over
        -- it puts the plate on again, and the gold is the plate's rather than the purse's.
        if ctx.hazard and ctx.hazard.plateOf == unit then
            ctx.consume()
            Status.apply(combat, unit, "status_gilt_plate", { magnitude = 1 })
            Combat.logEvent(combat, "action", string.format("%s puts the gilt plate back on.", name), unit)
            return
        end
        if unit.side == "party" then
            Combat.bounty(combat, gold)
            ctx.consume()
            Combat.logEvent(combat, "action", string.format("%s scoops up %d gold.", name, gold), unit)
            -- EVERY HAIR COVERED (data/traits/trait_every_hair_covered.lua): the looter is plated in it.
            if require("models.trait").flag(unit, "coveredInGold") then
                Status.apply(combat, unit, "status_every_hair_covered", { magnitude = 1 })
            end
            -- Counted for the fight, so a lead-in that is ABOUT taking gold (the Burglary, models/hoard.lua)
            -- can read how much was carried off when it is won.
            combat.heapsLooted = (combat.heapsLooted or 0) + 1
            require("models.golem").took(combat, unit) -- Heart of Gold heals the looter, once a turn
            local Trait = require("models.trait")
            for _, u in ipairs(combat.units or {}) do
                if u.alive and u.side ~= unit.side and seeks(u) then
                    Status.apply(combat, u, "status_gold_fever", { applier = unit })
                end
                -- EVERY COIN COUNTED: a hoard's owner knows the moment a heap goes (trait_the_hoard).
                if u.alive and u.side ~= unit.side and Trait.flag(u, "countsEveryCoin") then
                    Status.apply(combat, u, "status_every_coin_counted", { magnitude = 1 })
                    Combat.logEvent(combat, "action", string.format("%s knows a heap is gone.",
                        (u.char and u.char.name) or "It"), u)
                end
            end
        elseif seeks(unit) then
            unit.coffer = (unit.coffer or 0) + gold
            ctx.consume()
            Status.apply(combat, unit, "status_dragon_sickness", { magnitude = 1 })
            Combat.logEvent(combat, "action", string.format("%s pockets %d gold.", name, gold), unit)
        elseif eats(unit) then
            require("models.golem").eat(combat, unit, ctx.hazard)
        end
    end,
}
