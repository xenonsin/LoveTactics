-- Widen the Wound: the rogue's Bloodletting multiplier (docs/engines.md). It deals no damage at all; it
-- doubles the Bleed stacks a foe is already carrying. On a clean target it is a wasted turn, which is the
-- point -- the Catalyst of the engine, worth exactly what the blades before it laid down.
return {
    name = "Widen the Wound",
    description = "Doubles the target's Bleed stacks.",
    flavor = "The second cut follows the first.",
    sprite = "assets/items/ability_widen_the_wound.png",
    type = "ability",
    tags = { "physical" },
    class = "rogue",
    price = 240,
    unlockLevel = 7,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 3,
        cost = { stat = "stamina", amount = 6 },
        effect = function(fx)
            local Engine = require("models.engine")
            local n = Engine.bleedStacks(fx.target)
            if n <= 0 then
                fx.log("action", "There is no wound to widen.")
                return
            end
            fx.engine.addBleed(fx.target, n)
        end,
    },
}
