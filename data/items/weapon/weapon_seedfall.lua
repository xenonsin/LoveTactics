-- Seedfall: the Nymph drops a seed and a sapling stands up out of the floor.
--
-- WHY A NYMPH PLANTS. A fight board is eight by eight with a few blockers on it, so a line whose whole
-- idea is "the grain is ours" has to bring its own grain. The sapling is a small blocking body -- it
-- takes no turns, it can be cut down, and it stands in a lane like any other obstacle (so a shove into
-- it is a collision). It is also a PLANT (models/grove.lua), which is what the Nymph's Greenstep and the
-- Hamadryad's Through the Grain step between.
--
-- A summon with `noClaim`, so a Nymph can keep planting: a grove is several trees. They go when she does.
--
-- A natural weapon: no class, no price, noSteal (tests/bestiary_spec.lua).
return {
    name = "Yew-Seed", -- not the spell's name (ability_seedfall): see weapon_mistlight on why

    description = "Plants a sapling on an empty tile: a small blocking plant the grove steps between.",
    flavor = "It is a yew. It is always a yew. Nobody planted the first one either.",
    sprite = "assets/items/seedfall.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "nature", "magical", "summon" },
    noSteal = true,
    activeAbility = {
        target = "tile",
        range = 3,
        speed = 4,
        support = true,
        cost = { stat = "mana", amount = 6 },
        ai = {
            { priority = "normal", act = "cast", when = { subject = "any_foe", test = "within", value = 6 } },
        },
        effect = function(fx)
            fx.summon("character_sapling", fx.tx, fx.ty, { noClaim = true, control = "none", timeless = true })
        end,
    },
}
