-- DRAG INTO THE WHITE: the Dread of the Whiteout's second rule (data/items/utility/utility_drag_into_the_white.lua).
-- Approved 2026-10-04 on "Sloth's Bestiary", slice A.
--
-- At the top of her turn she hauls the nearest foe within `reach` that has no ally beside it up to `steps` tiles
-- toward her -- further from whoever it strayed from (a Rooted straggler arrives still Rooted: models/sloth_beasts.lua
-- lifts the Root for the haul and puts it back). Never be alone near her.
--
-- She took only a ROOTED body until the creature identity pass (2026-11-19) moved the yeti's roar off Root; the
-- straggler is the same body the roar frightens, so the pairing still reads, and she no longer needs a yeti to
-- have a rule at all.
local SlothBeasts = require("models.sloth_beasts")

return {
    name = "Drag Into the White",
    description = "At the start of its turn, hauls the nearest foe within 6 with no ally beside it three tiles toward it.",
    reach = 6,
    steps = 3,
    onTurnStart = function(ctx)
        local u = ctx.unit
        if not (u and u.alive) then return end
        SlothBeasts.drag(ctx.combat, u, ctx.param("reach", 6), ctx.param("steps", 3))
    end,
}
