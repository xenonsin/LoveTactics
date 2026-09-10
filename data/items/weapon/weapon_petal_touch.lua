-- A petal-drift's touch: it Charms, and it is not worth a turn to kill.
--
-- Both halves of that sentence are the mechanic. The Lust circle's swarm exists to make spending a real
-- ability feel like waste -- and holding your turn instead is exactly what the Suppliant behind it
-- drains you for (data/traits/trait_unasked.lua). The dilemma IS the floor.
--
-- A natural weapon: no class, no price, noSteal (tests/bestiary_spec.lua).
local Curve = require("models.curve")

return {
    name = "Petal Touch",
    description = "Brushes an adjacent foe and leaves Charm.",
    flavor = "It wants nothing at all. That is most of the trouble with it.",
    sprite = "assets/items/petal_touch.png",
    type = "weapon",
    class = "creature",
    dropTier = 8,
    tags = { "natural", "slash", "magical", "melee" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 2,
        cost = { stat = "stamina", amount = 3 },
        damage = Curve.ramp(2, 12),
        effect = function(fx)
            -- THE CHARM RIDES THE BLOW, and that is the whole of its accuracy. Applied on the line
            -- BELOW the damage, it landed on a MISS: docs/accuracy.md is unambiguous that a miss is a
            -- clean miss and takes the on-hit statuses with it, and this weapon simply was not asking.
            -- So the one mechanic the circle is built on ignored the dice -- every swing of it took a
            -- body, against any Avoid, on any ground, while the wound it rode in on rolled like
            -- everything else. `inflicts` carries the status INSIDE Combat.dealFlatDamage (a hammer's
            -- stun, the lancet's poison), which the miss gate in Combat.dealDamage never reaches, so
            -- the take now costs exactly the roll the wound costs.
            fx.damage(fx.target, { inflicts = "status_charm" })
        end,
    },
}
