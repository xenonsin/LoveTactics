-- Exsanguinate: the rogue's Bloodletting payoff (docs/engines.md). Every stack of Bleed on the target is
-- pulled out at once as RAW damage -- no armour, no resist -- and the wound closes behind it. The answer
-- to a wall of plate: a blade that cannot get through the coat can still leave the body bleeding under it.
--
-- Copies the shape of Boiling Blood (the mage's boss drop, which does the same with Burn), on the rogue's
-- own shelf and in its own resource.
return {
    name = "Exsanguinate",
    description = "Removes all Bleed from the target and deals 3 raw damage per stack.",
    flavor = "Everything the wound was going to cost, collected at once.",
    sprite = "assets/items/ability_exsanguinate.png",
    type = "ability",
    tags = { "physical", "bleed" },
    class = "rogue",
    price = 420,
    unlockLevel = 8,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 10 },
        perStack = 3,
        effect = function(fx)
            local Engine = require("models.engine")
            local n = Engine.bleedStacks(fx.target)
            if n <= 0 then
                fx.log("action", "The target is not bleeding.")
                return
            end
            fx.clearStatus(fx.target, Engine.BLEED)
            -- Flat and raw: what the wound was worth, with no wielder's arm added to it and no coat taken off.
            fx.flatDamage(fx.target, n * (fx.item.activeAbility.perStack or 3), { "physical", "bleed" })
        end,
    },
}
