-- THE BROKEN VOW: Furor's relic, the first thing his fall pays (Descent.DROPS). "Kill a sin, wear it": the monk
-- who lifts it lives under the asura's rule (models/asura.lua, trait_the_broken_vow) -- chi that also fills
-- when you are struck and drains on a turn you neither strike nor are struck, and a pool that, full, is not
-- yours to spend. At 10 the game takes the turn and throws the Burst at the nearest foe (status_bursting).
--
-- A GENERAL'S RELIC, and a MONK'S TROPHY (2026-10-01, "there can never be creature drops";
-- tests/sin_drops_spec.lua): a real class, `unstocked`, no price, nothing takes it off you -- shown on the
-- rack, refused as a monster drop, sold and bought back by nobody. `unlockLevel` is Furor's seat, floor ten.
-- It pairs with The
-- Held Breath -- a monk pinned low and soaking blows charges faster than one landing them.
-- The Burst is the organ's (utility_asura_blood): the same blow, costing nothing, open only at a full pool.
local Curve = require("models.curve")

return {
    name = "The Broken Vow",
    description = "Chi also fills when struck and drains on an idle turn. At full chi, Burst at the nearest foe.",
    flavor = "A prayer cord, knotted and then cut. The knots are still in it.",
    sprite = "assets/items/utility_the_broken_vow.png",
    type = "utility",
    tags = { "fist", "relic" },
    class = "monk",
    unlockLevel = 10,
    unstocked = true,
    noSteal = true, -- nothing takes this off you; you took it off him
    charge = { key = "chi", from = { "hitTaken" } },
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
