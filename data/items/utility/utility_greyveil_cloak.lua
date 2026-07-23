-- The Greyveil Cloak: thrown over somebody else. They go unseen, and what does reach them is muffled.
--
-- CONCEALMENT GRANTED TO AN ALLY, which nothing else here does. Every other vanishing in this game is
-- something a rogue does to itself -- Smoke Bomb, Vanishing Act, Stillshade -- and all of them are
-- escape hatches for the character who was already best at not being hit. This is a cloak you throw
-- over the party's PRIEST, and that is a different item entirely.
--
-- Which is the point: the unit the enemy most wants dead is almost never the one who can hide. Making
-- the healer untargetable for two turns does not save a fight the party is losing -- it makes the
-- fight they are winning finish, because the enemy has to spend those turns on somebody who can take
-- it.
--
-- The ward that comes with it is the honest half. Concealment says "you may not aim at me", and this
-- game has plenty of things that never aimed at anybody: a fireball on the tile, a hazard underfoot, a
-- Kept Wound bursting nearby. So the cloak adds a magical barrier -- one blast, swallowed whole --
-- because the blast is exactly how a hidden target dies.
--
-- IT IS UNDONE BY LIGHT. A Witchlight flare makes anything standing in it targetable whatever it is
-- wearing (Status.untargetable), so the counterplay exists, costs the enemy a consumable slot, and is
-- a thing the player can watch happen rather than a timer running out.
return {
    name = "The Greyveil Cloak",
    description = "Hides an ally from being targeted, and wards them against one magical blast.",
    flavor = "Undercroft work, sold openly. They are quite proud of how few questions that raises.",
    sprite = "assets/items/utility_greyveil_cloak.png",
    type = "utility",
    tags = { "dark" },
    class = "rogue",
    price = 360,
    repRank = 3,
    activeAbility = {
        target = "ally", -- includes the bearer, though throwing it over somebody else is the item
        range = 4,
        speed = 2, -- fast: it answers a threat that has already arrived
        cost = { stat = "mana", amount = 12 },
        support = true,
        effect = function(fx)
            fx.applyStatus(fx.target, "status_invisible", { duration = 10 + fx.level })
            -- The barrier is what makes it survive contact with an area caster, and it is authored in
            -- charges rather than size for the reason every ward in this game is: a thing that negates
            -- outright cannot negate harder, so the forge buys coverage.
            fx.applyStatus(fx.target, "status_magical_barrier", {
                magnitude = 1 + math.floor(fx.level / 4),
                duration = 10 + fx.level,
            })
        end,
    },
}
