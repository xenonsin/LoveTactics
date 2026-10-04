-- GRAFTED TROLL ARM: the Troll's second drop, on the Plague Knight's shelf (data/items/utility/
-- utility_grafted_troll_arm.lua). Approved 2026-10-04 ("Sloth's Bestiary", slice B).
--
-- A tenth of your health back at the top of every turn, with no exception for fire: half the troll's regrowth, and
-- none of its weakness. The price is the arm's: a heal from your own side does nothing to you (`refusesAllyHeals`,
-- read where a cast's heal knows its healer, models/combat.lua). A body you cannot heal is a body the company
-- has to plan around, which is the plague knight's whole shelf.
local REGROW = 0.1

return {
    name = "Grafted Troll Arm",
    description = "Regrow a tenth of your health each turn. Heals from allies do nothing to you.",
    refusesAllyHeals = true,
    onTurnStart = function(ctx)
        local u = ctx.unit
        if not (u and u.alive) then return end
        local Combat = require("models.combat")
        local max = Combat.unreservedMax(u.char, "health")
        if max - (u.char.stats.health.current or 0) > 0 then ctx.heal(u, math.max(1, math.floor(max * REGROW))) end
    end,
}
