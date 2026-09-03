-- Smite: the priest half of the Crusader (fighter x priest). A holy blow that leaves the ground it lands
-- on consecrated (data/hazards/hazard_heal.lua) -- allies who hold the tile heal, and the hazard knows
-- whose side it is on. Keeps the name the shelf always wanted; the priest's answer is a ZONE, not a
-- heal-on-kill. Carries `holy`, so demonic flesh takes far more (utility_demonic_essence.lua).
local Curve = require("models.curve")

return {
    name = "Smite",
    description = "Strikes for holy damage and consecrates the ground, granting Regeneration to allies who stand on it.",
    flavor = "The blow is for them. The ground it blesses is for you.",
    sprite = "assets/items/ability_smite.png",
    type = "ability",
    tags = { "holy", "impact" },
    class = "priest",
    discipline = "crusader", -- fighter x priest; the Smite mechanic's first stock
    price = 660,
    unlockQuests = 7,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "mana", amount = 10 },
        damage = Curve.ramp(13, 23), -- carries `holy` via the item tags
        effect = function(fx)
            fx.damage(fx.target)
            fx.placeHazard(fx.target.x, fx.target.y, "hazard_heal", { amount = 6 + fx.level, duration = 12 + fx.level })
        end,
    },
}
