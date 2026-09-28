-- EVERY ARM: Furor's signature, and his Burst (models/asura.lua). When his chi fills he does not throw the
-- plain Burst on his blood -- he winds up for a turn and then brings every arm he has grown down on one body:
-- one blow per pair of arms (up to four, at 8 chi and over), each a base plus 2 per chi spent.
--
-- The wind-up is the company's window, and its answer is the rule every wind-up in the game already has
-- (Combat.interruptChannel): shove him or move him and it breaks. His pool is still full when it does, so he
-- will wind up again -- which is the point: you are buying turns, not ending it. Reviewed on 2026-09-28, where
-- "cut an arm during the wind-up" was struck ("Don't cut arms") and the shove was approved in its place.
--
-- `asuraBurst = "signature"`: Asura.burstItem prefers it over the organ's plain Burst.
local Curve = require("models.curve")

return {
    name = "Every Arm",
    description = "Wind up, then consume all chi: one blow per pair of arms, each +2 damage per chi.",
    flavor = "The statues give him a thousand arms. This is why.",
    sprite = "assets/items/ability_every_arm.png",
    type = "ability",
    tags = { "fist", "physical", "melee" },
    class = "creature",
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 7,
        windup = 2, -- the tell: step off his line, or shove him off it
        asuraBurst = "signature",
        spendsCharge = "chi",
        unlock = {
            when = function(unit) return require("models.asura").full(unit) end,
            text = "Fill your chi",
        },
        damage = Curve.ramp(10, 20),
        description = "Wind up, then consume all chi: one blow per pair of arms, each +2 damage per chi.",
        effect = function(fx)
            local Asura = require("models.asura")
            local blows = 1 + ((fx.user.unarmedBonus and fx.user.unarmedBonus.hits) or 0) + Asura.grownHits(fx.user)
            local spent = fx.spendChi()
            for _ = 1, blows do
                if fx.target and fx.target.alive then fx.damage(fx.target, { amount = fx.amount + spent * 2 }) end
            end
        end,
    },
}
