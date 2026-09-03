-- Silence: seals a foe's mana pool for a duration, so it cannot cast anything that spends mana --
-- Combat.itemBlockReason reads the Silenced status and refuses those casts (see data/status/
-- silenced.lua). A stamina- or health-cost ability still fires: this gags a caster, it does not
-- disarm a soldier. Sight-gated, so cover shields a mage from being hushed across the board.
return {
    name = "Silence",
    description = "Inflicts Silence.",
    flavor = "It gags a caster. It does not disarm a soldier, and the Cathedral knows the difference.",
    sprite = "assets/items/ability_silence.png",
    type = "ability",
    tags = { "holy" },
    class = "exorcist", -- deeper cut of the shelf: buyable only once the exorcist gate is cleared
    price = 495,
    unlockQuests = 5,
    activeAbility = {
        target = "enemy",
        range = 3,
        requiresSight = true,
        speed = 4,
        cost = { stat = "mana", amount = 14 },
        effect = function(fx)
            fx.applyStatus(fx.target, "status_silenced")
        end,
    },
}
