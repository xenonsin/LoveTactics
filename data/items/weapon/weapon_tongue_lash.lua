-- TONGUE LASH: the Giant Toad's bite, which is not a bite. A sticky tongue that reaches two tiles and
-- leaves venom in what it touches (status_poison). Asked for on review (2026-09-25): "have a tongue basic
-- attack that applies poison".
--
-- THE REACH IS THE POINT. Two tiles lets the toad hit the body it means to eat over the shoulder of the one
-- in front of it -- and a poisoned body is one the company is already spending a Cure on, which is a turn
-- it is not spending on emptying the toad. Spit (ability_toad_spit) starts where this ends, so the two
-- never cover the same ground.
--
-- A natural weapon: creature kit, no price, noSteal.
local Curve = require("models.curve")

return {
    name = "Tongue Lash",
    description = "Lashes a foe up to 2 tiles away and inflicts Poison.",
    flavor = "It is out and back before the eye agrees it happened. The sting stays.",
    sprite = "assets/items/weapon_tongue_lash.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "physical", "melee", "impact" },
    noSteal = true, -- the tongue is the toad's
    activeAbility = {
        target = "enemy",
        range = 2,
        speed = 3,
        cost = { stat = "stamina", amount = 4 },
        damage = Curve.ramp(4, 14),
        effect = function(fx)
            fx.damage(fx.target, { inflicts = "status_poison" })
        end,
    },
}
