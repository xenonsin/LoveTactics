-- A lightning elemental's natural weapon. A shocking strike that carries the "lightning" tag, so it
-- reaps the bonus damage on any foe left Wet (by rain, or by a water elemental's Tide Fists) -- the
-- water-and-lightning pairing the mage's kit is built around. `noSteal`: the storm is not yours to take.
return {
    name = "Storm Fists",
    description = "Shock an adjacent foe; strikes harder against the Wet.",
    sprite = "assets/items/storm_fists.png",
    type = "weapon",
    tags = { "lightning", "magical", "melee" },
    noSteal = true,
    activeAbility = {
        name = "Shock",
        target = "enemy",
        range = 1,
        speed = 2,
        cost = { stat = "stamina", amount = 5 },
        power = 7,
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
