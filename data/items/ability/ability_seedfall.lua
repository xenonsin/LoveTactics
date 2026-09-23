-- Seedfall: plant a sapling on an empty tile -- a small blocking plant that stands in a lane like any
-- other obstacle, and that the grove's other spells step between (models/grove.lua).
--
-- A WALL YOU CAN PUT BEHIND SOMEBODY. On an open board most shoves spend every tile they have, and
-- Combat.knockback only bills the ones it could not spend: a sapling behind a foe is a collision waiting
-- for a mace. It is also the grain Greenstep and Through the Grain need, so it is the first druid spell
-- of the three and the cheapest. Several may stand at once (a grove is several trees), and they fall
-- with their planter.
return {
    name = "Seedfall",
    description = "Plants a sapling on an empty tile: a small blocking plant.",
    flavor = "It is a yew. It is always a yew.",
    sprite = "assets/items/ability_seedfall.png",
    type = "ability",
    tags = { "nature", "summon" },
    class = "druid",
    price = 255,
    unlockLevel = 4,
    activeAbility = {
        target = "tile",
        range = 3,
        speed = 3,
        support = true,
        cost = { stat = "mana", amount = 6 },
        effect = function(fx)
            fx.summon("character_sapling", fx.tx, fx.ty, { noClaim = true, control = "none", timeless = true })
        end,
    },
}
