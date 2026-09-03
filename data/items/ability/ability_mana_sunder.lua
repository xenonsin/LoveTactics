-- Mana Sunder: the knight half of the Spellbreaker. A strike that burns a caster's mana to nothing
-- (fx.drain -- taken, not stolen) AND Silences it: not a momentary interrupt but a hard lockout, the
-- pool gone and the casting sealed both. Sloth's answer to pride -- it does not out-cast the mage, it
-- takes casting away.
local Curve = require("models.curve")

return {
    name = "Mana Sunder",
    description = "Strikes a foe, burns its mana away, and inflicts Silenced.",
    flavor = "Not the spell. The saying of spells.",
    sprite = "assets/items/ability_mana_sunder.png",
    type = "ability",
    tags = { "impact", "physical" },
    class = "spellbreaker", -- knight x mage; the Counterspell mechanic's first stock
    price = 660,
    unlockQuests = 7,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 9 },
        damage = Curve.ramp(14, 24),
        restore = Curve.ramp(10, 30), -- fx.amount: the mana burned off
        effect = function(fx)
            -- The Silence rides the blow, so a guardian who takes the strike is the one gagged.
            fx.damage(fx.target, { inflicts = "status_silenced" })
            fx.drain(fx.target, "mana", fx.amount) -- burned, not siphoned: the Spellbreaker keeps nothing
        end,
    },
}
