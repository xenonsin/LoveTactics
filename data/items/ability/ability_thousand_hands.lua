-- THOUSAND HANDS: Furor's arms as a move, for a company monk (Descent.DROPS). Asura Strike puts every point of
-- chi into one body; this spends the same pool as a spray -- one bare-handed blow for every 2 chi, dealt round
-- every foe in reach, the aimed one first. Each blow is the bearer's own fist (fx.strikeWith, like Flurry's),
-- so Swift Fist, the Asura's Arm and every fist charm apply to each of them.
local Curve = require("models.curve")

return {
    name = "Thousand Hands",
    description = "Consume all chi. Strike bare-handed once per 2 chi, spread across every foe in reach.",
    flavor = "Nobody standing near him ever agreed on how many there were.",
    sprite = "assets/items/ability_thousand_hands.png",
    type = "ability",
    tags = { "fist", "physical" },
    class = "monk",
    unstocked = true,
    unlockLevel = 8,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 6,
        cost = { stat = "stamina", amount = 8 },
        spendsCharge = "chi",
        unlock = {
            when = function(unit) return require("models.combat").chi(unit) >= 2 end,
            text = "Gather 2 chi",
        },
        damage = Curve.ramp(2, 12),
        description = "Consume all chi. Strike bare-handed once per 2 chi, spread across every foe in reach.",
        effect = function(fx)
            local fists = fx.user.char and fx.user.char.unarmed
            local blows = math.floor(fx.spendChi() / 2)
            if not fists or blows <= 0 then return end
            local foes = { fx.target }
            for _, u in ipairs(fx.unitsNear(fx.user.x, fx.user.y, 1)) do
                if u ~= fx.target and u.alive and u.side ~= fx.user.side then foes[#foes + 1] = u end
            end
            for i = 1, blows do
                local t = foes[((i - 1) % #foes) + 1]
                if t and t.alive then fx.strikeWith(fists, t.x, t.y) end
            end
        end,
    },
}
