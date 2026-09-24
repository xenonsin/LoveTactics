-- HIGH WIND: the Highwing going up to hunt rather than to hide. Three turns riding high (status_high_wind):
-- still on the board and still a target, but +30 Avoid, a tile more on its Wind Shear, and no Root takes.
-- It comes down in a Stoop (ability_stoop, which spends the status) or when the wind runs out.
return {
    name = "High Wind",
    description = "For three turns: +30 Avoid, +1 range, and immune to Root.",
    flavor = "The others go up to get away. This one goes up to look.",
    sprite = "assets/items/ability_high_wind.png",
    type = "ability",
    class = "creature",
    tags = { "wind" },
    noSteal = true,
    activeAbility = {
        target = "self",
        range = 0,
        support = true,
        speed = 3,
        cooldown = 30, -- six turns: three up, three on the ground
        cost = { stat = "stamina", amount = 8 },
        effect = function(fx)
            fx.applyStatus(fx.user, "status_high_wind")
        end,
    },
}
