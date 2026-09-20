-- THE KING'S REACH: a spear of somebody, at length.
--
-- The Skeleton King's own weapon, and the one piece of its kit that is not a rule. A boss's identity is
-- machinery (the Barrow Crown is the machinery), so what this has to do is much smaller: hold the party
-- one tile further out than they want to be, so a company that has just spent its turn clearing the
-- court cannot also close and swing in the same beat.
--
-- REACH 2, which is the whole of it. The court arrives on the King's flanks
-- (data/items/ability/ability_call_the_court.lua) and the King hits past them, so standing off is not
-- the shelter it looks like -- the two rules are one board.
--
-- SLASH, on the orchard's standing joke: everything on that side of the board swings the damage type
-- its own frame turns aside. Creature stock -- unpriced, `noSteal`, on nobody's shelf.
local Curve = require("models.curve")

return {
    name = "The King's Reach",
    description = "Cuts a foe up to two tiles away.",
    flavor = "Long enough that the front rank was never his problem. It has not been his problem for some centuries now.",
    sprite = "assets/items/the_kings_reach.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "slash", "physical", "melee" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 2,
        speed = 5,
        cost = { stat = "stamina", amount = 8 },
        --        level:  0  1  2  3  4  5  6  7  8  9  10
        damage = Curve.ramp(16, 28),
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
