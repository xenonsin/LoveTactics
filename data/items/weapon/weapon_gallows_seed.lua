-- Gallows Seed: the Alraune plants a seed in a foe, and every heal that foe receives is hers.
--
-- The rule is the status's (data/status/status_gallows_seed.lua, read by Combat.applyHeal): the whole
-- heal is drawn off to the planter, and the host gets nothing. The sting on the way in is small --
-- the seed is the cast, the wound is its excuse -- and the seed is gated on the hit, so a miss plants
-- nothing (docs/accuracy.md).
--
-- A natural weapon: no class, no price, noSteal (tests/bestiary_spec.lua). A company can carry the
-- spell itself out of her garden: ability_gallows_seed.
local Curve = require("models.curve")

return {
    name = "Gallows Bloom", -- not the spell's name (ability_gallows_seed): see weapon_mistlight on why
    description = "Plants a seed in a foe: every heal it receives goes to her instead.",
    flavor = "What grows under a gallows is fed. Nobody asks what with.",
    sprite = "assets/items/gallows_seed.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "nature", "magical", "ranged" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 4,
        requiresSight = true,
        speed = 5,
        cost = { stat = "mana", amount = 10 },
        damage = Curve.ramp(2, 12),
        effect = function(fx)
            local dealt = fx.damage(fx.target)
            if dealt > 0 and fx.target.alive then fx.applyStatus(fx.target, "status_gallows_seed") end
        end,
    },
}
