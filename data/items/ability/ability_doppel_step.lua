-- DOPPEL-STEP: the Doppelganger's drop. Reviewed 2026-10-01..03 ("Envy's Bestiary"); the author asked for the drop
-- to be on a cooldown rather than once a fight, and for it to be the ninja's.
--
-- The Doppelganger's trick at a person's size: wear an exact copy of any body in sight -- an ally's kit to cover a
-- hole in the line, or a foe's to turn its own answer back at it -- until the end of your next turn. A transform,
-- so your health is the pool you walked in with (models/transform.lua); the copy is Summon.copyChar's, the same
-- body a Faceless takes a companion's face in. Doppel-Step's badge owns the shape and ends it.
--
-- Not on the copy's own grid while you wear it, which is fine: you are already somebody else.
return {
    name = "Doppel-Step",
    description = "Become an exact copy (stats and kit) of any body, ally or foe, until the end of your next turn. Your health stays yours.",
    flavor = "The first lesson is to stand like them. The second is to stop being surprised when it works.",
    sprite = "assets/items/ability_doppel_step.png",
    type = "ability",
    tags = { "guile", "illusion", "utility" },
    class = "ninja",
    unlockLevel = 12,
    unstocked = true,
    activeAbility = {
        target = "unit",
        range = 4,
        speed = 3,
        requiresSight = true,
        support = true, -- a shape you put on, not a blow you land
        cooldown = 20,
        cost = { stat = "stamina", amount = 8 },
        effect = function(fx)
            local t = fx.target
            -- A body with a grid to copy: the tooltip's stand-in target has none.
            if not (t and t.char and t.char.inventory and t ~= fx.user) then return end
            local copy = require("models.masks").exactCopy(t.char)
            if fx.transform(fx.user, nil, { char = copy }) then
                fx.applyStatus(fx.user, "status_doppel_step")
            end
        end,
    },
}
