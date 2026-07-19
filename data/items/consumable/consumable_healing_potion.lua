return {
    name = "Healing Potion",
    description = "Restores health to an ally.",
    flavor = "The Crucible's steadiest seller. Nobody has ever haggled over one twice.",
    sprite = "assets/items/potion.png",
    type = "consumable",
    tags = { "potion", "restorative" },
    class = "alchemist",
    price = 35,
    repRank = 1,
    activeAbility = {
        target = "ally", -- includes the user (a unit is its own ally)
        range = 1,
        speed = 2,
        consumesItem = true, -- removed from inventory after use
        healing = { 30, 33, 36, 39, 42, 45, 48, 51, 54, 57, 60 }, -- the amount restored; Power is the balance knob for the heal too
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
