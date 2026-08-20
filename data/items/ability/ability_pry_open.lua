-- Pry Open: the rogue half of the Vanguard's Breach. A precise strike that levers a foe's guard aside --
-- Sundered (data/status/status_sundered.lua): guards, reflexes and traits go quiet -- so the next blow,
-- from anyone, lands clean. Greed's guile pointed at a shield instead of a purse.
local Curve = require("models.curve")

return {
    name = "Pry Open",
    description = "Strikes a foe and inflicts Sundered.",
    flavor = "Every lock is a promise that the door will hold. She has never once believed one.",
    sprite = "assets/items/ability_pry_open.png",
    type = "ability",
    tags = { "pierce", "physical", "guile" },
    class = "rogue",
    discipline = "vanguard", -- knight x rogue; the Breach mechanic's first stock
    price = 610,
    unlockQuests = 4,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 3,
        cost = { stat = "stamina", amount = 6 },
        damage = Curve.ramp(12, 22),
        effect = function(fx)
            fx.damage(fx.target, { inflicts = "status_sundered" })
        end,
    },
}
