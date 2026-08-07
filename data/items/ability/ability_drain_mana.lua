-- Drain Mana: siphon a foe's mana into the caster's own reserves. Takes up to fx.amount from the
-- target's mana (Combat.drainResource, which reports what it actually removed) and restores exactly
-- that much to the caster -- a foe with an empty pool yields nothing. `restore` is the leveled
-- magnitude field (fx.amount), so the siphon grows as the item is forged.
local Curve = require("models.curve")

return {
    name = "Drain Mana",
    description = "Siphons a foe's mana into your own reserves.",
    flavor = "The Undercroft steals what the Arcanum insists cannot be stolen.",
    sprite = "assets/items/ability_drain_mana.png",
    type = "ability",
    tags = { "guile", "utility" },
    class = "rogue",
    price = 140,
    unlockQuests = 1,
    activeAbility = {
        target = "enemy",
        range = 3,
        requiresSight = true,
        speed = 4,
        cost = { stat = "stamina", amount = 4 },
        restore = Curve.ramp(8, 20), -- fx.amount: the mana siphoned
        effect = function(fx)
            local taken = fx.drain(fx.target, "mana", fx.amount)
            fx.restore(fx.user, "mana", taken)
        end,
    },
}
