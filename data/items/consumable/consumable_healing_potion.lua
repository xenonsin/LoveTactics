local Curve = require("models.curve")

return {
    name = "Healing Potion",
    description = "Restores health to an ally.",
    flavor = "The Crucible's steadiest seller. Nobody has ever haggled over one twice.",
    sprite = "assets/items/potion.png",
    type = "consumable",
    tags = { "potion", "restorative" },
    class = "alchemist",
    price = 35,
    -- OPENING SHELF. It sat at 1 for as long as the Cafe resold it un-gated, so the gate only ever
    -- decided which door a new player bought their first heal through, never whether they could. The
    -- Cafe sells suppers now (models/meal.lua), and a house whose own flavor line calls this "the
    -- Crucible's steadiest seller" cannot be the house you must run an errand for before it will sell
    -- you one.
    unlockQuests = 0,
    activeAbility = {
        target = "ally", -- includes the user (a unit is its own ally)
        range = 1,
        speed = 2,
        consumesItem = true, -- removed from inventory after use
        healing = Curve.ramp(30), -- the amount restored; Power is the balance knob for the heal too
        -- An NPC carrying one drinks it when it is genuinely in trouble, not at the first scratch:
        -- the potion is consumed, so a rule that fires early throws the item away for a few points.
        -- `emergency` -- above even a Heal aimed at someone else -- because a unit that is about to
        -- die saves itself first, and there is no later in which to do it.
        ai = { priority = "emergency", act = "support", targetPref = "lowest_hp",
               when = { subject = "self", test = "hp_pct_below", value = 0.35 } },
        effect = function(fx)
            fx.heal(fx.target, fx.amount) -- restore Power HP via the shared heal helper
        end,
    },
}
