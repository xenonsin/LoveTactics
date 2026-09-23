-- Gallows Seed: plant a seed in a foe, and every heal it receives comes to you instead
-- (data/status/status_gallows_seed.lua, read by Combat.applyHeal).
--
-- The Alraune's hook, carried out of her garden. Against a line with a healer it is two spells in one:
-- their priest's turn lands on you, and the body it was meant for goes without. Against a line without
-- one it is a small sting and a badge -- which is the honest price of a trick that answers exactly one
-- kind of enemy. A Cure pulls it. `unstocked`: a trophy, off the Alraune line and nowhere else.
local Curve = require("models.curve")

return {
    name = "Gallows Seed",
    description = "Plants a seed in a foe: every heal it receives comes to you instead.",
    flavor = "What grows under a gallows is fed. Now you know what with.",
    sprite = "assets/items/ability_gallows_seed.png",
    type = "ability",
    tags = { "nature", "magical" },
    class = "druid",
    unstocked = true,
    unlockLevel = 4,
    activeAbility = {
        target = "enemy",
        range = 4,
        requiresSight = true,
        speed = 4,
        cost = { stat = "mana", amount = 10 },
        damage = Curve.ramp(9, 19),
        effect = function(fx)
            local dealt = fx.damage(fx.target)
            if dealt > 0 and fx.target.alive then fx.applyStatus(fx.target, "status_gallows_seed") end
        end,
    },
}
