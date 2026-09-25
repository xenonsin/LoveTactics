-- SHALE PLATING: the Earth Golem's drop (round 1, "The Golems of Greed"). Shed Plate, worn by the company:
-- three plates of shale, +1 Defense each, and an impact blow sheds one as a rubble wall on the clear tile
-- behind you -- away from whoever struck it (trait_shed_plate, status_shale_plate). Armour lost, cover
-- gained exactly where the heavy hitter pushed you. It grows back between fights.
return {
    name = "Shale Plating",
    description = "Opens each fight with three plates (+1 Defense each). An impact blow sheds one as a rubble wall behind you.",
    flavor = "Layered like the rock it came off, and it comes off the same way.",
    sprite = "assets/items/utility_shale_plating.png",
    type = "utility",
    tags = { "earth" },
    class = "bulwark",
    unlockLevel = 5,
    traits = { "trait_shed_plate" },
    traitParams = { plateStatus = "status_shale_plate", plates = 3, shedAs = "rubble" },
}
