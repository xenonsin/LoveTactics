-- An Ordnance Sentry's crossbow arm (data/characters/character_ordnance_sentry.lua): the `natural`
-- family, a construct's own body rather than a thing anybody forged to sell.
--
-- `requiresSight` and a two-tile dead zone, exactly as an iron bow has, because the sentry IS a bow that
-- somebody bolted to the floor -- it should be answerable the same way one is. The engine cannot walk
-- backward out of trouble (movement 0), so closing to point-blank is the entire counterplay to it, and
-- the dead zone is what makes that counterplay exist. Take that away and an emplacement would be a
-- turret with no wrong angle, which is a different and much worse item.
return {
    name = "Sentry Bolt",
    description = "A tripod-mounted crossbow arm. No shot closer than two tiles.",
    flavor = "It does not aim so much as wait for the aim to become correct.",
    sprite = "assets/items/sentry_bolt.png",
    type = "weapon",
    tags = { "natural", "pierce", "physical", "ranged" },
    noSteal = true, -- a construct's body is not loot
    activeAbility = {
        target = "enemy",
        range = 4,
        minRange = 2,       -- the wrong angle, and the only one it has
        requiresSight = true,
        speed = 5,
        cost = { stat = "stamina", amount = 4 },
        --        level:  0  1  2  3  4  5  6  7  8  9  10
        damage = { 6, 7, 7, 8, 9, 9, 10, 11, 11, 12, 13 },
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
