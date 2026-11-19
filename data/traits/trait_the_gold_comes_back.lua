-- THE GOLD COMES BACK: the Gilded King's plates find their way home (2026-11-19, the creature identity pass).
--
-- The review's note on him: a blow knocks a plate off, so he softens per hit -- and the heaps that fall are
-- never used. They were a payout with no decision in it. So now a heap left lying BESIDE him is a plate
-- he gets back: at the start of his turn, one coin heap on any of the eight tiles around him is drawn back
-- onto him as a Gold Plate (never past the plates he opened with). The company answers it two ways, and
-- both are on the board: LOOT the heap first (step on it and the gold is banked -- hazard_coin_heap), or
-- fight him AWAY from it. A plate lands on the side away from whoever struck it (trait_shed_plate), so the
-- heaps pile up behind him, and taking them means going round.
--
-- One heap a turn, not all of them: a company that hits him four times and loots none still gains on him,
-- and the lesson is meant to be "loot as you go", not "you must loot or never win".
--
-- Not the golem's Regild (trait_eats_heaps): that one EATS a heap it walks onto and heals. The King never
-- walks for it and never heals -- he cannot be healed at all (trait_turned_to_gold) -- the gold simply
-- climbs back on.
local Status = require("models.status")

local RING = { { 0, -1 }, { 1, 0 }, { 0, 1 }, { -1, 0 }, { 1, -1 }, { 1, 1 }, { -1, 1 }, { -1, -1 } }

return {
    name = "The Gold Comes Back",
    grade = 1.0, -- weighed beside the rule (Grade.traitValue reads it): one plate a turn, and only off a heap beside him
    description = "At the start of his turn, a coin heap beside him goes back on as a gold plate.",
    notAReaction = true,
    onTurnStart = function(ctx)
        local combat, unit = ctx.combat, ctx.unit
        if not (unit and unit.alive) then return end
        local status = ctx.param("plateStatus", "status_gold_plate")
        local cap = ctx.param("plates", 6)
        if Status.stacksOf(unit, status) >= cap then return end
        local Hazard = require("models.hazard")
        for _, d in ipairs(RING) do
            local heap = Hazard.at(combat, unit.x + d[1], unit.y + d[2], "hazard_coin_heap")
            if heap and heap.alive ~= false then
                Hazard.consume(combat, heap)
                Status.apply(combat, unit, status, { magnitude = 1 })
                ctx.log("action", string.format("The gold beside %s climbs back on.",
                    (unit.char and unit.char.name) or "him"), unit)
                return
            end
        end
    end,
}
