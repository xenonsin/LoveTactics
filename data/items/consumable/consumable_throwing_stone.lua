-- Crucible rank-1. The cheapest thing on the shelf: a fist-sized rock. No powder, no reaction --
-- just something to throw at a foe that stays out of reach. A single-target physical hit at a
-- distance, weak on its own, but it costs almost nothing and it is a consumable, which is the point:
-- it is the free target for the Crucible's charms. An Alchemic Mastery or Long-Fuse Reagent beside a
-- stack of stones turns a trivial throw into a cheap, repeatable poke -- and an Everflask makes the
-- stack eternal.
return {
    name = "Stone",
    description = "Deals physical damage to a foe at range.",
    flavor = "The cheapest thing on the Crucible's shelf, and the humblest thing its charms will consent to empower.",
    sprite = "assets/items/throwing_stone.png",
    type = "consumable",
    tags = { "physical" },
    class = "alchemist",
    price = 15,
    repRank = 1,
    maxStack = 12, -- ammunition: a fuller stack than the default 9
    activeAbility = {
        target = "enemy",
        range = 4,
        requiresSight = true,
        speed = 4,
        cost = { stat = "stamina", amount = 2 },
        damage = { 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10 }, -- flat: a thrown rock hits the same however strong the arm
        consumesItem = true,
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
