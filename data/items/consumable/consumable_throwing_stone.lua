-- The cheapest thing in the arena: a fist-sized rock. No powder, no reaction -- just something to
-- throw at a foe that stays out of reach. A single-target physical hit at a distance, weak on its
-- own, and on the opening rack at thirty gold, which is the whole point: it is the first answer
-- anybody can afford to "he is over there and I am not".
--
-- IT BORROWS THE ALCHEMIST'S WORD, AND SAYS SO. `consumesItem` and throwables are the Crucible's
-- vocabulary (docs/classes.md), and this sits on the Colosseum's rack anyway, because the thing is
-- not a reagent -- it is a rock, and a crowd that wants blood throws them. The Crucible's charms
-- still find it across the two shelves, which is what mixed shelves are for: an Alchemic Mastery or
-- a Long-Fuse Reagent beside a stack of stones turns a trivial throw into a cheap, repeatable poke,
-- and an Everflask makes the stack eternal.
local Curve = require("models.curve")

return {
    name = "Stone",
    description = "Deals damage to a foe.",
    flavor = "The cheapest thing on the sand, and the first thing the crowd reaches for.",
    sprite = "assets/items/throwing_stone.png",
    type = "consumable",
    tags = { "physical" },
    class = "fighter",
    price = 30,
    unlockQuests = 0,
    maxStack = 12, -- ammunition: a fuller stack than the default 9
    activeAbility = {
        target = "enemy",
        range = 4,
        requiresSight = true,
        speed = 4,
        cost = { stat = "stamina", amount = 2 },
        damage = Curve.ramp(5, 15), -- flat: a thrown rock hits the same however strong the arm
        consumesItem = true,
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
