-- THE SLOW CIRCLE: what a company carries out of the coils, and it is the lamia's own string.
--
-- A lamia spends its fight deciding that you do not get to be anywhere else
-- (data/characters/character_lamia.lua). This is that, handed over: what the bearer's melee bites is
-- tethered to the bearer, and pays for every turn it ends outside the circle. See
-- data/traits/trait_the_slow_circle.lua for the cooldown and why it is melee only.
--
-- IT IS HALF OF A PAIR, and its other half falls off the same circle: utility_constrictors_due makes
-- every blow land harder on a body that is already held. One puts things in a hold and the other bills
-- for it, and neither is worth much without a way to get the other -- which is what a stratum's drop
-- table should feel like.
--
-- `class` IS THE VENDOR SHELF AND NEVER AN EQUIP GATE (docs/classes.md). The Sentinel is where "you do
-- not get to walk away from me" is already written down -- a guard whose whole discipline is being the
-- body other people's attacks have to come through -- not who is allowed to carry a rope.
--
-- FOUND IN THE RIFT, NOT DEALT OVER A COUNTER (docs/shelf.md): no `price`, so a counter stocks it only
-- once the class has climbed to its rung.
return {
    name = "The Slow Circle",
    description = "Your melee blows tether a foe to you. It pays to end its turn away from you.",
    flavor = "She lets go of everything, eventually. It is the letting go that she is slow about.",
    sprite = "assets/items/the_slow_circle.png",
    type = "utility",
    tags = { "charm", "dark" },
    class = "sentinel",
    unlockLevel = 7,
    traits = { "trait_the_slow_circle" },
}
