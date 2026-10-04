-- SPLINTER OF THE MIRROR: the Snow Queen's shard, lifted off her for a spellbreaker ("Sloth's Bestiary", 2026-10-04,
-- approved word for word). A strike that leaves the foe Cold-Hearted for 2 turns (status_cold_hearted): it cannot
-- heal, buff or aid its allies. The spellbreaker's trade is taking away what a foe does for its side, and this takes
-- the healer's hand off the line for two turns. The status rides the blow, so a guardian who takes it is the one
-- frozen. An unstocked trophy on the approach's rung.
local Curve = require("models.curve")

return {
    name = "Splinter of the Mirror",
    description = "Inflicts Cold-Hearted for 2 turns: it cannot heal, buff or aid its allies.",
    flavor = "Small enough to miss. That is how it gets in.",
    sprite = "assets/items/ability_splinter_of_the_mirror.png",
    type = "ability",
    tags = { "ice", "pierce", "physical" },
    class = "spellbreaker",
    unlockLevel = 9,
    unstocked = true,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 9 },
        damage = Curve.ramp(12, 22), -- the slot-9 target (tests/balance_spec.lua)
        effect = function(fx)
            fx.damage(fx.target, { inflicts = { id = "status_cold_hearted", duration = 10 } })
        end,
    },
}
