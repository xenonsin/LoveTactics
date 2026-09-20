-- A slime's natural weapon: it leans a part of itself onto you. Not a limb -- there is nothing in
-- there to be a limb -- so the blow lands as weight rather than as an edge, and `impact` is the only
-- physical family word that honestly describes it.
--
-- IT IS ALSO THE BODY'S ONLY WAY TO SPEND WHAT IT DRINKS. data/traits/trait_adaptive.lua declares
-- `carriesWardedElement`, which Combat.strikeElement reads off the element the bearer is currently
-- proof against and folds into this blow's tag set -- so an unadapted slime leans on you and one that
-- has swallowed a Fireball burns you with it, off a single authored tag list. That is the same
-- mechanism the Battlemage's Resonant Grip uses, with a different memory behind it, which is why this
-- weapon declares no element of its own: the element is the fight's, not the blueprint's.
--
-- No `class`/`price` and `noSteal`: a creature's body is not loot (docs/bestiary.md).
--
-- SLOW AND HEAVY, the Great Claws bargain. A thing with no bones does not jab; it arrives. That is
-- also what keeps a body the party cannot answer with steel from being a body the party cannot
-- outrun -- the whole counterplay to a slime is time, and this is where the time comes from.
local Curve = require("models.curve")

return {
    name = "Pseudopod",
    description = "Leans a mass of itself onto an adjacent foe.",
    flavor = "It does not reach for you. It simply comes to be where you are standing.",
    sprite = "assets/items/pseudopod.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "impact", "physical", "melee" },
    noSteal = true, -- a creature's body is not loot
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 6, -- ponderous, like the bear's: it lands once for what a sword lands twice
        cost = { stat = "stamina", amount = 10 },
        --        level:  0  1  2  3  4  5  6  7  8  9  10
        damage = Curve.ramp(14, 26),
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
