-- OATHBOUND PLATE: the Death Knight's trophy (data/characters/character_death_knight.lua; "The Crown's Bestiary",
-- slice B, approved 2026-10-09). The knight's Bulwark of the Fallen handed over at half strength: when an ally
-- within 3 falls, the bearer gains a Physical Barrier worth a quarter of that ally's max health
-- (trait_bulwark_of_the_fallen, `share = 0.25`). A Sentinel's, because standing over the fallen is that house.
local Curve = require("models.curve")

return {
    name = "Oathbound Plate",
    description = "When an ally within 3 falls, gain a Physical Barrier of a quarter of their max health.",
    flavor = "The oath was to the Crown. The plate never learned the difference between that and the dead.",
    sprite = "assets/items/armor_oathbound_plate.png",
    type = "armor",
    tags = { "plate" },
    class = "sentinel",
    unlockLevel = 15,
    unstocked = true,
    traits = { "trait_bulwark_of_the_fallen" },
    traitParams = { share = 0.25 },
    bonus = { defense = Curve.ramp(6, 16), movement = -1 },
}
