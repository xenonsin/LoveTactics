-- Transfusion: the priest half of the Apothecary (priest x alchemist). Lend your own vitality to an
-- ally -- it draws health from the caster (fx.drain) and pours exactly that much into the target
-- (fx.heal). A gift that costs the giver, which is the Apothecary's whole voice: the cure is real, and
-- somebody paid for it in the same coin.
local Curve = require("models.curve")

return {
    name = "Transfusion",
    description = "Heals an ally, draining the same amount from your own health.",
    flavor = "The vial is empty. It was always going to be one of you.",
    sprite = "assets/items/ability_transfusion.png",
    type = "ability",
    tags = { "restorative" },
    class = "priest",
    discipline = "apothecary", -- priest x alchemist; the Lent-vitality mechanic's first stock
    price = 740,
    unlockQuests = 11,
    activeAbility = {
        target = "ally", -- an ally other than yourself is the point; self-targeting is a wash
        range = 2,
        speed = 3,
        healing = Curve.ramp(18, 38), -- fx.amount: the vitality moved
        effect = function(fx)
            local given = fx.drain(fx.user, "health", fx.amount)
            if given > 0 then fx.heal(fx.target, given) end
        end,
    },
}
