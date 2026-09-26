-- THE UNBROKEN AXE: the orc Berserker's drop (approved as pitched, 2026-09-26, "The Orcs of Wrath"). The streak
-- without the compulsion: +2 Damage for each turn in a row this axe landed a hit, up to +10, and a turn without one
-- resets it (trait_unbroken, status_unbroken). It never makes you swing. An axe, so it cleaves like every axe
-- (docs/weapons.md). Worn beside Warpaint, the longer streak counts rather than both.
local Curve = require("models.curve")

return {
    name = "Unbroken Axe",
    description = "Deals damage in area. Each turn in a row it lands a hit, increase damage by 2, up to 10.",
    flavor = "The edge is a ruin and the haft has been replaced four times. It is the same axe. Ask the orc.",
    sprite = "assets/items/weapon_unbroken_axe.png",
    type = "weapon",
    tags = { "axe", "slash", "physical", "melee" },
    class = "barbarian",
    unlockLevel = 7,
    unstocked = true,
    traits = { "trait_unbroken" },
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 1,
        minRange = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 10 },
        damage = Curve.ramp(10, 22),
        aoe = { shape = "front", width = 3 },
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do fx.damage(u) end
        end,
    },
}
