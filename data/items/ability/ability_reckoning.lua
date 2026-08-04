-- Reckoning: the Crusader's spender (fighter x priest). Empties the Zeal pool into one holy blow -- and
-- mends every ally standing beside the crusader for the same amount it dealt.
--
-- Both halves from one cast, which is the argument for the discipline existing. A fighter's spender does
-- damage; a priest's does mending; the Crusader's does exactly one thing and it is both, so there is
-- never a turn where the crusade has to choose which of its two jobs it is doing today. That is also why
-- the heal is the damage rather than a separate number: they cannot be tuned apart, and a build that
-- wanted only one of them would still be paying for the other.
--
-- Zeal is banked by the Tabard and the Vow, from kills and mends anywhere on the field (R2), so nothing
-- about reaching this depends on holding a particular weapon. `unlock.when` reads the shared pool
-- directly, as every charge spender does -- a counted unlock would keep a per-item baseline and quietly
-- give this file its own private Zeal.
--
-- Note it REBANKS as it resolves: the mending it does is `healDone`, which is one of Zeal's own sources,
-- so the cast hands back a point on the way out. Deliberate, and the same rebate Flurry takes -- a
-- crusade that spends itself empty on one blow and is credited nothing for the mercy in it would be
-- teaching the player not to stand near their own allies.
local Curve = require("models.curve")

return {
    name = "Reckoning",
    description = "Consume all Zeal for a holy blow, +3 damage per point, healing adjacent allies as much as it dealt.",
    flavor = "The account had been open a long while. She closed it in one motion, for everyone at once.",
    sprite = "assets/items/ability_reckoning.png",
    type = "ability",
    tags = { "holy", "impact" },
    class = "fighter",
    discipline = "crusader",
    price = 380,
    unlockQuests = 7,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 5,
        cost = { stat = "stamina", amount = 8 },
        damage = Curve.ramp(6, 16),
        unlock = {
            when = function(unit) return require("models.combat").chargePool(unit, "zeal") >= 1 end,
            text = "Bank Zeal by felling and healing",
        },
        description = "Consume all Zeal; +3 damage per point, and every adjacent ally is healed for what it dealt.",
        effect = function(fx)
            local spent = fx.spendCharge("zeal")
            local dealt = fx.damage(fx.target, { amount = fx.amount + spent * 3 })
            -- The mend is what the blow actually LANDED, not what it was aimed at: a strike that broke
            -- on armour mends little, which keeps the heal honest against a wall of plate and stops the
            -- ability being a party heal that happens to be pointed at somebody.
            if dealt <= 0 then return end
            for _, u in ipairs(fx.unitsNear(fx.user.x, fx.user.y, 1)) do
                if u.alive and u.side == fx.user.side and u ~= fx.user then fx.heal(u, dealt) end
            end
        end,
    },
}
