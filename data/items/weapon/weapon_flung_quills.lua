-- Flung Quills: the raven form's natural weapon (data/characters/character_wild_raven.lua). It throws
-- its own pinion feathers -- stiffened, edged things loosed with a beat of the wing -- which is the only
-- way a bird was ever going to hold a hunter's reach.
--
-- THE POINT OF THE WHOLE FORM. Wild Shape strips the hunter's kit and hands back the beast's body, so
-- the wolf (Fangs, range 1) and the bear (Great Claws, range 1) both make the same trade: give up the
-- bow, become the thing that closes. This is the form that refuses that trade -- the one shape a hunter
-- can wear and still be shooting when the turn comes back around.
--
-- It keeps the DEAD ZONE that every bow in this game keeps (minRange 2, see docs/weapons.md): a bird
-- with a mouthful of feathers has nothing to do with a swordsman already inside its wings. That gap is
-- what the Fan of Feathers (data/items/ability/ability_fan_of_feathers.lua) exists to answer, and why
-- the form carries both -- reach while they are far, a sweep the moment they are not.
--
-- `natural`, `noSteal`, sold by nobody: a creature's body is not loot (models/item.lua), which is also
-- what keeps it out of the bow family's roster of five (tests/weapon_spec.lua).
return {
    name = "Flung Quills",
    description = "Looses a stiffened pinion feather at a foe two or three tiles off.",
    flavor = "It sheds them on purpose. Whatever is left in the wing is the part it still needs.",
    sprite = "assets/items/flung_quills.png",
    type = "weapon",
    tags = { "natural", "pierce", "physical", "ranged" },
    noSteal = true, -- a creature's body is not loot
    activeAbility = {
        target = "enemy",
        range = 3,
        minRange = 2, -- the bow's dead zone, kept: a bird cannot fling a feather at its own chest
        requiresSight = true,
        speed = 4,
        cost = { stat = "stamina", amount = 4 },
        --        level:  0  1  2  3  4  5  6  7   8   9  10
        damage = { 6, 6, 7, 8, 8, 9, 10, 10, 11, 12, 12 },
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
