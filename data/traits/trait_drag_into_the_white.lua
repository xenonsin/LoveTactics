-- DRAG INTO THE WHITE: the Dread of the Whiteout's second rule (data/items/utility/utility_drag_into_the_white.lua).
-- Approved 2026-10-04 on "Sloth's Bestiary", slice A.
--
-- At the top of her turn she hauls the nearest Rooted foe within `reach` up to `steps` tiles toward her -- away from
-- whoever it was standing with, and still Rooted when it arrives (models/sloth_beasts.lua lifts the Root for the
-- haul and puts it back). The yeti's roar does the rooting; she does the taking. Kill the escort, or never be alone.
local SlothBeasts = require("models.sloth_beasts")

return {
    name = "Drag Into the White",
    description = "At the start of its turn, hauls the nearest Rooted foe within 6 three tiles toward it.",
    reach = 6,
    steps = 3,
    onTurnStart = function(ctx)
        local u = ctx.unit
        if not (u and u.alive) then return end
        SlothBeasts.drag(ctx.combat, u, ctx.param("reach", 6), ctx.param("steps", 3))
    end,
}
