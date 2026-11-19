-- Shield Slam: the knight's Rampart payoff (docs/engines.md). Raw damage equal to the barrier you are
-- holding, and the barrier stays. Body Slam: the knight's guard is its weapon, and the turn it spent
-- raising one is the turn it spent sharpening the other. Renamed from the round's working name Shield
-- Bash, which an existing ability already carries.
--
-- `class = "knight"` with NO `price`: unbuyable, and still tallying toward knight growth
-- (docs/classes.md, "class without price").
--
-- Reworked from Forty-One Marks (2026-11-18), a plain damage charm. The id stays for saves.
return {
    name = "Shield Slam",
    description = "Deals raw damage equal to your barrier. The barrier stays.",
    flavor = "Every knight of the Bastion has done it once by accident. The good ones do it on purpose.",
    sprite = "assets/items/forty_one_marks.png",
    type = "ability",
    tags = { "impact", "physical" },
    class = "knight",
    unlockLevel = 3,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 6 },
        counter = function(unit)
            return unit and require("models.engine").barrierPool(unit) or 0
        end,
        counterEmpty = "No barrier to slam with",
        effect = function(fx)
            local have = require("models.engine").barrierPool(fx.user)
            if have <= 0 then return end
            fx.flatDamage(fx.target, have, { "impact", "physical" })
        end,
    },
}
