-- STARLIGHT: the Elf Starcaller's own cast (reworked 2026-10-01, "Pride's Bestiary"). Witchlight on every tile
-- around a foe, three by three -- laid onto an occupied tile it takes effect at once (Hazard.place treats the
-- occupant as an entry), so whoever stands in it is Limned where they stand. That is what By Starlight reads: the
-- Starcaller lights the company, then casts at the light.
--
-- The answer is the light's own: step out of it before the next bolt, or kill the caster that keeps relighting it.
return {
    name = "Starlight",
    description = "Lays Witchlight over every tile around a foe, Limning whoever stands there.",
    flavor = "The stars come out on the spire whenever an elf wants something to see by.",
    sprite = "assets/items/ability_starlight.png",
    type = "ability",
    class = "creature",
    tags = { "light", "magical" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 4,
        requiresSight = true,
        speed = 4,
        cooldown = 10,
        cost = { stat = "mana", amount = 8 },
        aoe = { shape = "square", radius = 1 },
        ai = { priority = "high", act = "cast" },
        effect = function(fx)
            for _, c in ipairs(fx.aoeCells()) do fx.placeHazard(c.x, c.y, "hazard_witchlight") end
        end,
    },
}
