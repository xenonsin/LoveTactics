-- CASTOFF COAT: Moult rebuilt as a coat (trait_castoff). Once a fight, at half health, the wearer steps
-- out of it -- every harmful status left in the empty sleeves -- and is out of sight until their next
-- turn. Off the Larder Mother; a trophy.
local Curve = require("models.curve")

return {
    name = "Castoff Coat",
    description = "Once, at half health: shed every harmful status and go Invisible until your next turn.",
    flavor = "It is a skin. It was worn, it was outgrown, and it is still better armour than yours.",
    sprite = "assets/items/armor_castoff_coat.png",
    type = "armor",
    tags = { "hide" },
    class = "poacher",
    unlockLevel = 6,
    unstocked = true,
    traits = { "trait_castoff" },
    bonus = { defense = Curve.ramp(2, 12), movement = -1 },
}
