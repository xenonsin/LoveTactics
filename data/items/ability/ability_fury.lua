-- Fury: burn the candle at both ends. Casting it drops the caster to 1 HP and opens a berserk window
-- (the Fury status, data/status/fury.lua): for its duration the caster CANNOT die -- any blow leaves
-- it standing at 1 -- and every point of damage it deals is banked. When the window closes, and only
-- then, it heals for half of everything it dealt while raging. Go all in: the more you spend, the more
-- comes back -- if you can keep swinging long enough to collect.
return {
    name = "Fury",
    description = "Drop to 1 HP and become unkillable for a spell; then heal for half the damage you dealt.",
    sprite = "assets/items/ability_fury.png",
    type = "ability",
    tags = { "physical" },
    class = "fighter",
    price = 420,
    repRank = 4,
    activeAbility = {
        target = "self",
        range = 0,
        speed = 5,
        cost = { stat = "stamina", amount = 10 },
        effect = function(fx)
            -- Applying Fury both drops the caster to 1 HP and opens the berserk window (see the
            -- status's onApply). Kept in the status so a dry-run preview -- which stubs applyStatus --
            -- never mutates the real unit's health.
            fx.applyStatus(fx.user, "fury")
        end,
    },
}
