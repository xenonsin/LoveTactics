-- An ability that jolts a foe: light magical damage plus the "status_stun" status, which shoves the
-- target down the turn order (see data/status/stun.lua). Demonstrates fx.applyStatus from an ability.
local Curve = require("models.curve")

return {
    name = "Jolt",
    description = "Deals lightning damage and inflicts Stun.",
    flavor = "The apprentice's shock, grown up: the same idea, with a storm behind it.",
    sprite = "assets/items/ability_jolt.png",
    type = "ability",
    tags = { "lightning", "magical" },
    class = "mage",
    price = 560,
    unlockQuests = 8,
    activeAbility = {
        target = "enemy",
        range = 3,
        requiresSight = true, -- a bolt needs a clear line: terrain cover blocks it
        -- Slower than a sword swing, and that is the price of what it buys: an ability that hands you
        -- the initiative should cost some of your own to throw.
        --
        -- IT NO LONGER TEACHES THE PROLOGUE, and that is why it is allowed to hit. Jolt used to be both
        -- the Arcanum's opening spell and the village lesson's teaching cast, so its weight answered to
        -- the choreography instead of to the shelf -- a stun on a bolt is a large thing to carry, and
        -- nothing could say so without breaking the lesson's closing beat. The lesson now has its own
        -- spell (data/items/ability/ability_minor_shock.lua) with these numbers as they stood when the
        -- prologue was written around them, and Jolt is graded for what it does.
        speed = 4,
        cost = { stat = "mana", amount = 5 },
        damage = Curve.ramp(12, 22),
        -- The delay, tuned on its own axis and upgraded on its own curve. It used to be read off the
        -- damage roll, which welded the spell's two halves together: pinning the tempo it sells to how
        -- hard it hits capped the one thing it is really for.
        --
        -- Scales faster than the damage does, which is the point of the split: forging a Jolt should
        -- buy TIME, not a better hit. That is what makes it worth its rung -- two thirds of a turn taken
        -- off whoever it lands on, on top of a bolt that now hits like the shelf it sits on.
        stun = Curve.ramp(10),
        effect = function(fx)
            -- power + the caster's MagicDamage, minus MagicDefense. The stun rides the blow so it
            -- lands before the target can react to it, and carries its own authored magnitude.
            fx.damage(fx.target, {
                inflicts = { id = "status_stun", magnitude = fx.item.activeAbility.stun },
            })
        end,
    },
}
