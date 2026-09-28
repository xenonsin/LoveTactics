-- ASURA BLOOD: what every asura is (data/races/asura.lua grants it). The monk's chi, with the discipline gone
-- (models/asura.lua): it fills when the asura is struck as well as when it strikes, it drains on an idle turn,
-- and at a full pool the asura BURSTS -- the Burst below, thrown at the nearest foe, whether it would or not.
--
-- The Burst is the Asura Strike's own arithmetic (data/items/ability/ability_asura_strike.lua): a base plus six
-- per chi, spending the whole pool. It sits on the organ rather than on the monk shelf's ability so the Acolyte,
-- which carries no Asura Strike, still has one to throw; and it costs nothing, because a compulsion that could
-- stall for want of stamina would not be one. Its `unlock` opens only at a full pool, so the planner never
-- reaches for it as a choice -- it is only ever the thing the Bursting status makes it do (Asura.plan).
local Curve = require("models.curve")

return {
    name = "Asura Blood",
    description = "Chi also fills when struck and drains on an idle turn. At full chi, Burst at the nearest foe.",
    flavor = "It sat longer than anyone has ever sat, and it got up angry.",
    sprite = "assets/items/utility_asura_blood.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    charge = { key = "chi", from = { "hitTaken" } },
    -- TAPAS: a Gather (the Centering Charm's coil) banks 2 chi, and a coiled turn is not an idle one.
    gatherCharge = 2,
    traits = { "trait_the_broken_vow" },
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 7,
        asuraBurst = true,
        spendsCharge = "chi",
        unlock = {
            when = function(unit) return require("models.asura").full(unit) end,
            text = "Fill your chi",
        },
        damage = Curve.ramp(10, 20),
        description = "Consume all chi at once. Increase damage by 6 per chi.",
        effect = function(fx)
            local spent = fx.spendChi()
            fx.damage(fx.target, { amount = fx.amount + spent * 6 })
        end,
    },
}
