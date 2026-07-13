-- A wind elemental's natural weapon. A fast, cutting gust -- the quickest of the elemental strikes
-- (speed 1), matching the wind elemental's darting movement -- carrying the "wind" tag. `noSteal`:
-- there is nothing solid to lift.
return {
    name = "Gale Fists",
    description = "Slash an adjacent foe with a cutting gust. Very fast.",
    sprite = "assets/items/gale_fists.png",
    type = "weapon",
    tags = { "wind", "magical", "melee" },
    noSteal = true,
    activeAbility = {
        name = "Gust",
        target = "enemy",
        range = 1,
        speed = 1,
        cost = { stat = "stamina", amount = 4 },
        damage = { 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10 },
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
