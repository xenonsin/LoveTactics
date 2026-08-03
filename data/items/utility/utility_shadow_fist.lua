-- Shadow Fist: a strike that reaches farther than an arm should. A passive "fist" charm that extends
-- the range of the bearer's bare-handed strike by one tile (`unarmedBonus.range`, added to the unarmed
-- ability's reach in Combat.abilityRange) -- so the fist can jab a foe a tile away. Only the fist is
-- lengthened, never a crafted weapon. Stacks with the other fist charms.
local Curve = require("models.curve")

return {
    name = "Shadow Fist",
    description = "Bare-handed strikes reach one tile farther. Does nothing for a weapon.",
    flavor = "An arm does not do that. The Cathedral's monks decline to discuss which part is the arm.",
    sprite = "assets/items/shadow_fist.png",
    type = "utility",
    tags = { "fist" },
    class = "priest",
    discipline = "monk", -- deeper cut of the shelf: buyable only once the monk gate is cleared
    price = 260,
    unlockQuests = 6,
    unarmedBonus = { range = Curve.ramp(1) },
}
