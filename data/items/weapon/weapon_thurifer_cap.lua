-- The Thurifer's cap: it swings its own head like a censer, and the spores come off it like smoke.
--
-- THE CENSER'S MECHANIC ON A NATURAL WEAPON. `incense` lays hazard_spore_cloud in a square around the
-- bearer, lifted and laid again wherever it goes (Combat.layIncense), exactly as the Cathedral's censers
-- carry Incense and Choking Fumes -- sided to the bearer, so the mushroom folk breathe it freely and a
-- foe standing beside a Thurifer swoons. Not tagged `censer`: that is the shop family and its contract
-- (docs/weapons.md), and nobody forges a mushroom. The company's own censer that walks this cloud is
-- weapon_spore_censer, which is.
--
-- The swing is an afterthought, as a censer's always is -- and a demon's blow burns (docs/bestiary.md).
-- A natural weapon: no class, no price, noSteal (tests/bestiary_spec.lua).
local Curve = require("models.curve")

return {
    name = "Thurifer's Cap",
    description = "Carries a cloud that Swoons foes beside it. Its swing is an afterthought.",
    flavor = "Incense is what a church burns so that nobody notices what else is in the air.",
    sprite = "assets/items/thurifer_cap.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "impact", "physical", "fire", "melee" },
    noSteal = true,
    incense = { hazard = "hazard_spore_cloud", radius = 1 },
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 4 },
        damage = Curve.ramp(3, 13),
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
