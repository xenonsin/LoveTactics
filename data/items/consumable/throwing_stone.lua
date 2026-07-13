-- Crucible rank-1. The cheapest thing on the shelf: a fist-sized rock. No powder, no reaction --
-- just something to throw at a foe that stays out of reach. A single-target physical hit at a
-- distance, weak on its own, but it costs almost nothing and it is a consumable, which is the point:
-- it is the free target for the Crucible's charms. An Alchemic Mastery or Long-Fuse Reagent beside a
-- stack of stones turns a trivial throw into a cheap, repeatable poke -- and an Everflask makes the
-- stack eternal.
return {
    name = "Stone",
    description = "A fist-sized rock. Cheap to throw, and the humblest thing an alchemist empowers.",
    sprite = "assets/items/throwing_stone.png",
    type = "consumable",
    tags = { "physical" },
    class = "alchemist",
    price = 15,
    repRank = 1,
    maxStack = 12, -- ammunition: a fuller stack than the default 9
    activeAbility = {
        name = "Throw Stone",
        target = "enemy",
        range = 4,
        requiresSight = true,
        speed = 4,
        cost = { stat = "stamina", amount = 2 },
        power = 5, -- flat: a thrown rock hits the same however strong the arm
        consumesItem = true,
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
