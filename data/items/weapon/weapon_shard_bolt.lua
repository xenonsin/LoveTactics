-- SHARD-BOLT: the Snow Queen's natural weapon ("Sloth's Bestiary", 2026-10-04, approved: "Splinter: a body her
-- shard-bolt strikes becomes Cold-Hearted"). A splinter of her mirror, thrown.
--
-- The Cold-Hearted rides the blow (`inflicts`), so a guardian who takes the bolt is the one whose heart freezes, and
-- the hover names it. Three turns, unless fire or a Cure takes it off sooner (status_cold_hearted). ICE and MAGICAL.
-- A natural weapon: no class, no price, noSteal.
local Curve = require("models.curve")

return {
    name = "Shard-Bolt",
    description = "Inflicts Cold-Hearted.",
    flavor = "Everything it touches looks smaller afterwards, and a little uglier, and not worth helping.",
    sprite = "assets/items/weapon_shard_bolt.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "ice", "magical", "ranged" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 4,
        requiresSight = true,
        speed = 4,
        cost = { stat = "mana", amount = 6 },
        damage = Curve.ramp(6, 16),
        effect = function(fx)
            fx.damage(fx.target, { inflicts = "status_cold_hearted" })
        end,
    },
}
