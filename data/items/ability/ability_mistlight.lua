-- Mistlight: the Nymph's light, carried out of the Rood Loft. A foe it finds cannot hide, and the next
-- shove that lands on it throws it one tile further (data/status/status_mistlit.lua, spent by
-- Combat.knockback).
--
-- WHAT IT BUYS A COMPANY is every shove it already owns: a mace's two tiles become three, a Shield
-- Shove's one becomes two, and Combat.knockback bills the impact of every tile a shove could not spend.
-- It does nothing on its own, which is why it is cheap.
--
-- DRUID, on the shelf the grove's spells stock once found (the Dryad line's drops): the growing half of
-- the druid, beside the wild shapes that are its changing half.
return {
    name = "Mistlight",
    description = "Lights a foe: it cannot hide, and the next shove throws it one tile further.",
    flavor = "Travellers follow it off the road. It is a comfort to know that works in both directions.",
    sprite = "assets/items/ability_mistlight.png",
    type = "ability",
    tags = { "nature", "utility" },
    class = "druid",
    price = 210,
    unlockLevel = 3,
    activeAbility = {
        target = "enemy",
        range = 4,
        requiresSight = true,
        speed = 3,
        cost = { stat = "mana", amount = 6 },
        effect = function(fx)
            fx.applyStatus(fx.target, "status_mistlit")
        end,
    },
}
