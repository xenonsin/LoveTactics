-- Answering Blow: the payoff half of the Champion's Riposte-wall (fighter x knight). Spends every point
-- of Defiance banked by Defiant Stand and turns all the way round with the blade out -- every adjacent
-- foe takes a blow whose weight is the punishment already absorbed.
--
-- The arithmetic is the argument: what you get back is exactly what you stood there and took. A Champion
-- who spent the turn safe has nothing to spend, and the button is greyed until it does (`unlock.when`
-- reads the shared pool, exactly as Flurry does -- a counted `unlock.event` would keep a PER-ITEM
-- baseline and give this and Defiant Stand two different pools called Defiance).
--
-- Scaled per point rather than per body, so it stays honest when it lands on one foe: the reward is for
-- weathering, not for being surrounded. Reprisal already pays for the crowd.
--
-- It declares Defiance itself, off the same tally its unlock text names -- blows weathered. A spender
-- that banked nothing was inert until you also owned Defiant Stand, which made the payoff half of the
-- discipline unusable on its own shelf. Defiant Stand is still what a Champion wants: it TAUNTS, which
-- is the difference between waiting to be hit and asking for it, and it carries the deeper cap.
local Curve = require("models.curve")

return {
    name = "Answering Blow",
    description = "Consume all Defiance to strike every adjacent foe. Increase damage by 4 per point spent.",
    flavor = "He had been keeping a tally. He read it out to all of them at once.",
    sprite = "assets/items/ability_answering_blow.png",
    type = "ability",
    tags = { "impact", "physical" },
    class = "fighter",
    discipline = "champion",
    price = 740,
    unlockQuests = 11,
    -- Shallower than Defiant Stand's 6 and Crowd's Favour's 8: the spender opens the pool, the rest of
    -- the Champion shelf deepens and widens it (Combat.chargeDef merges).
    charge = { key = "defiance", from = { "hitTaken" }, max = 4 },
    activeAbility = {
        target = "self",
        range = 0,
        -- The ring of neighbours. fx.aoeUnits narrows it to whom a Careful Sigil beside it allows,
        -- and the self-target means the footprint is centred on the Champion rather than aimed.
        aoe = { radius = 1, shape = "square" },
        speed = 5,
        cost = { stat = "stamina", amount = 8 },
        damage = Curve.ramp(15, 25), -- the floor; Defiance is what makes it a blow
        unlock = {
            when = function(unit) return require("models.combat").chargePool(unit, "defiance") >= 1 end,
            text = "Bank Defiance by weathering blows",
        },
        description = "Consume all Defiance. Every adjacent foe takes the blow, +4 per point spent.",
        effect = function(fx)
            local spent = fx.spendCharge("defiance")
            for _, u in ipairs(fx.aoeUnits()) do
                if u.side ~= fx.user.side then
                    fx.damage(u, { amount = fx.amount + spent * 4 })
                end
            end
        end,
    },
}
