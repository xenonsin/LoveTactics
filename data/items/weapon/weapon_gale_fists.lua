-- A wind elemental's natural weapon. A fast, cutting gust -- the quickest of the elemental strikes
-- (speed 1), matching the wind elemental's darting movement -- carrying the "wind" tag. `noSteal`:
-- there is nothing solid to lift.
return {
    name = "Gale Fists",
    description = "Slashes an adjacent foe with a cutting gust.",
    flavor = "There is nothing solid to lift off it, and nothing solid to strike back at.",
    sprite = "assets/items/gale_fists.png",
    type = "weapon",
    tags = { "natural", "wind", "magical", "melee" },
    noSteal = true,
    activeAbility = {
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
