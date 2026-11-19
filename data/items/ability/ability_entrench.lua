-- Entrench: the knight's Rampart multiplier (docs/engines.md). Double the barrier you are holding, and
-- plant your feet: you are Rooted. Priced in position rather than in power: a knight that entrenches
-- has chosen where the fight will be.
--
-- A new item beside the Tower Shield, which keeps its heavy brace (the author's "keep both", round 2).
return {
    name = "Entrench",
    description = "Doubles your barrier. You are Rooted.",
    flavor = "The Bastion teaches its recruits to dig before it teaches them to swing.",
    sprite = "assets/items/ability_entrench.png",
    type = "ability",
    tags = { "physical" },
    class = "knight",
    price = 300,
    unlockLevel = 6,
    activeAbility = {
        target = "self",
        range = 0,
        speed = 3,
        support = true,
        cost = { stat = "stamina", amount = 8 },
        effect = function(fx)
            local have = require("models.engine").barrierPool(fx.user)
            if have > 0 then fx.engine.grantBarrier(fx.user, have) end
            fx.applyStatus(fx.user, "status_root")
        end,
    },
}
