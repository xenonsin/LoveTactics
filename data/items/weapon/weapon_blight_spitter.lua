-- A Blightstake's spitter: the fouled reed in its head, which is the whole of its kit. Not sold, not
-- stolen, not carried by anything with hands -- it exists so the stake has something to answer with,
-- the way a wolf's fangs and an elemental's burning hands do.
--
-- A `natural` weapon, which is the family for exactly this (see Item.ARCHETYPES): a creature's own
-- body, granted by a blueprint's startingItems, owing no shared mechanic beyond that. Unpriced and
-- classless, so no vendor stocks it and it feeds no growth tally.
--
-- Poison rather than damage, and the numbers say so plainly: the hit itself is barely worth reporting,
-- and everything the stake is worth is on the clock it starts. That is the point of the summon -- see
-- data/items/ability/ability_blightstake.lua -- and this file is where it is actually paid.
return {
    name = "Blight Spitter",
    description = "Inflicts Poison.",
    flavor = "Whatever is in the cloth was alive once, and is now extremely motivated.",
    sprite = "assets/items/weapon_blight_spitter.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "poison", "physical" },
    noSteal = true, -- it is part of the stake, not equipment
    activeAbility = {
        target = "enemy",
        range = 3,
        requiresSight = true,
        speed = 5,
        damage = 3, -- token: the clock below is the weapon
        effect = function(fx)
            fx.damage(fx.target, { inflicts = "status_poison" })
        end,
    },
}
