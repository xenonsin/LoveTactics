-- The gilded rank's pike. An ordinary weapon, deliberately.
--
-- Everything interesting about a Pride body is positional: Close Ranks and Formation Fighter both read
-- adjacency live off the board, so the same pike is enormous in line and unremarkable out of it. A
-- weapon that also did something would make it impossible to tell which of the two was happening.
--
-- Reach 2, because a rank fights over the shoulder of the one in front. That is also what makes a
-- formation actually hold a doorway rather than merely stand behind one.
--
-- A natural weapon: no class, no price, noSteal (tests/bestiary_spec.lua). Gilded stock is animate
-- armour, not a knight -- it is what somebody's pride was poured into.
local Curve = require("models.curve")

return {
    name = "Gilded Pike",
    description = "Strikes a foe up to two tiles away.",
    flavor = "Nobody is holding it. It has been at the correct angle for four hundred years.",
    sprite = "assets/items/gilded_pike.png",
    type = "weapon",
    class = "creature",
    dropTier = 4,
    tags = { "natural", "pierce", "physical", "melee" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 2,
        speed = 3,
        cost = { stat = "stamina", amount = 5 },
        damage = Curve.ramp(7, 17),
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
