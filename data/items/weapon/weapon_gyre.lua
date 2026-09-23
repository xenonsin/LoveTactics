-- THE GYRE: the Whirl Elemental's rush to a tile the wind picks, cutting everything it passes over and
-- throwing whoever stands where it comes down.
--
-- THE SAME CAST AS THE WHIRLWIND, borrowed whole (data/items/ability/ability_whirlwind.lua argues every
-- rule of it). Two files because the body and the company hold it under two contracts: this one is
-- creature kit -- no class, no price, noSteal -- and the Whirlwind is the barbarian trophy the body drops
-- when it falls. Into the Green and Greenstep are the same pair (weapon_greenstep.lua), and like them
-- the natural copy wears its own name, so a log line and a tooltip never confuse the animal's rush with
-- the thing the company carried out.
--
-- WHY THIS BODY WANTS A RUSH IT CANNOT AIM. Every tile it moves through is a chance to scatter fire
-- (utility_flue_throat's `trail.scatter`), and every burn it lays is a handhold for the Chimney-Draw. A
-- rush it did not choose still sets the room alight on the way, and still delivers it into the middle
-- of somebody -- which is where both of its other hands want it.
--
-- A natural weapon: no class, no price, noSteal (tests/bestiary_spec.lua).
local Whirlwind = require("data.items.ability.ability_whirlwind")

-- A shallow copy, so this blueprint's table is its own and never an alias of the trophy's.
local activeAbility = {}
for k, v in pairs(Whirlwind.activeAbility) do activeAbility[k] = v end

return {
    name = "Gyre",
    description = Whirlwind.description,
    flavor = "The roof has been lifting off that building one slate at a time for three hundred years.",
    sprite = "assets/items/gyre.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "wind", "slash", "physical" },
    noSteal = true,
    activeAbility = activeAbility,
}
