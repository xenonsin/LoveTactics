-- SEVERING BLOW: the asura line's counterplay turned into a fighter's move, and the Colosseum's own piece off
-- its circle's general (Descent.DROPS). A heavy blow; one that lands for at least a fifth of the target's
-- maximum health takes its weapon off it (Disarmed). Fists still work -- which is the joke an asura would
-- make of it. A fighter trophy: unstocked, seen on the Colosseum's rack and never sold.
local Curve = require("models.curve")

return {
    name = "Severing Blow",
    description = "A heavy blow. If it deals at least a fifth of the target's max health, inflicts Disarm.",
    flavor = "Aimed at the wrist. Nobody has ever complained that it went higher.",
    sprite = "assets/items/ability_severing_blow.png",
    type = "ability",
    tags = { "slash", "physical", "melee" },
    class = "fighter",
    unstocked = true,
    unlockLevel = 8,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 6,
        cost = { stat = "stamina", amount = 9 },
        damage = Curve.ramp(10, 26),
        description = "A heavy blow. If it deals at least a fifth of the target's max health, inflicts Disarm.",
        effect = function(fx)
            local t = fx.target
            if not t then return end
            local dealt = fx.damage(t) or 0
            local hp = t.char and t.char.stats and t.char.stats.health
            local max = hp and hp.max or 0
            if max > 0 and dealt * 5 >= max and t.alive then
                fx.applyStatus(t, "status_disarmed")
            end
        end,
    },
}
