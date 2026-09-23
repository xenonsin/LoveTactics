-- The Spore Censer: the Thurifer's cap, hollowed and hung on a chain. Its cloud Swoons every foe beside
-- the bearer (hazard_spore_cloud), lifted and laid again wherever the priest walks.
--
-- A THIRD VOICE FOR THE CATHEDRAL'S CENSERS, and the one that finally makes the family's standing claim
-- about Lust true in the other direction: Incense blesses the line, Choking Fumes poisons the foe, and
-- this takes the foe's will to strike -- the circle's own verb, carried out of it. A priest who walks
-- into a melee with this is a priest the melee cannot swing at until somebody hits it awake.
--
-- A CENSER BY CONTRACT (docs/weapons.md, tests/weapon_spec.lua): it emits, it does not swap Wait, and
-- the strike is an afterthought. `unstocked`: a trophy, off the Thurifer and nowhere else.
local Curve = require("models.curve")

return {
    name = "Spore Censer",
    description = "Inflicts Swoon on adjacent foes.",
    flavor = "Incense is what a church burns so that nobody notices what else is in the air.",
    sprite = "assets/items/weapon_spore_censer.png",
    type = "weapon",
    tags = { "censer", "impact", "physical", "melee" },
    class = "priest",
    unstocked = true,
    unlockLevel = 7,
    incense = {
        hazard = "hazard_spore_cloud",
        radius = 1,
    },
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 6 },
        damage = Curve.ramp(9, 19), -- feeble on purpose: the smoke is the weapon
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
