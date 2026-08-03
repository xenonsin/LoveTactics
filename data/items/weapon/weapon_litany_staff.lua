-- Litany Staff: the priest half of the Theurge (mage x priest). A staff, so it swaps Wait into Focus
-- (docs/weapons.md -- end the turn to recover mana), which is the Theurge's engine: the channelled
-- miracles are hungry, and this is what feeds them from the field instead of from town. Its own strike
-- carries `holy`, feeble on purpose like every staff's -- the Focus swap is the weapon, the litany is
-- what the mana is for.
local Curve = require("models.curve")

return {
    name = "Litany Staff",
    description = "Replaces Wait with Focus to recover mana; its holy strike is a feeble afterthought.",
    flavor = "The words are old and the staff is only for holding while you say them.",
    sprite = "assets/items/weapon_litany_staff.png",
    type = "weapon",
    tags = { "staff", "magical", "holy", "melee" },
    class = "priest",
    discipline = "theurge", -- mage x priest; the Channelled-miracle mechanic's first stock
    price = 240,
    unlockQuests = 6,
    waitBehavior = { kind = "focus", mana = Curve.ramp(9, 19), speed = 10 },
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 6 },
        damage = Curve.paired(4, 9), -- feeble: the Focus swap is the real weapon
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
