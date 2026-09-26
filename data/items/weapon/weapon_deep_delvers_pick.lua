local Curve = require("models.curve")

-- THE DEEP-DELVER'S PICK: the Dwarf Skeleton's. The Delver's arrival made a payoff: the first blow you land
-- after you surface from any go-under -- a Delve, Through the Rock -- is a critical (trait_deep_delver).
-- Saboteur stock, beside the Delve it pays off; it pairs with the wight's Through the Rock.
return {
    name = "Deep-Delver's Pick",
    description = "The first blow you land after surfacing from a Delve or Through the Rock is a critical.",
    flavor = "It went through a great deal of mountain before it went through the dwarf.",
    sprite = "assets/items/weapon_deep_delvers_pick.png",
    type = "weapon",
    tags = { "hammer", "impact", "physical", "melee" },
    class = "saboteur",
    unlockLevel = 5,
    unstocked = true,
    traits = { "trait_deep_delver" },
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 5,
        cost = { stat = "stamina", amount = 8 },
        damage = Curve.ramp(16, 26),
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
