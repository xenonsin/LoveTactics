-- SCALE BLESSING: the Kobold Scale-Priest's gift to a kinsman -- a scale of the dragon's, pressed to its
-- hide (status_dragonscale: +3 Defense, about two turns). Creature kit, the priest's own, not for sale.
return {
    name = "Scale Blessing",
    description = "Grants an ally Dragonscale.",
    flavor = "The scale is always the same scale. It goes back into the priest's pouch afterwards.",
    sprite = "assets/items/ability_scale_blessing.png",
    type = "ability",
    tags = { "blessing" },
    class = "creature",
    noSteal = true,
    activeAbility = {
        target = "ally",
        range = 3,
        speed = 3,
        support = true,
        cooldown = 10,
        cost = { stat = "mana", amount = 6 },
        effect = function(fx)
            fx.applyStatus(fx.target, "status_dragonscale")
        end,
    },
}
