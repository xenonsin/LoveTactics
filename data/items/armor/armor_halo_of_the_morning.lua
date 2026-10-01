-- HALO OF THE MORNING: Superbia's Light-Bearer for a person (reviewed over three rounds, "Pride's Generals"). A foe
-- that starts its turn able to see the bearer is Blinded until that turn ends -- its Skill cut, so its aim with it
-- (trait_light_bearer, status_blind).
--
-- A Crusader's coat, because a crusader is the one who means to be seen: the rule pays a body that stands in the
-- open and is looked at. Medium, so it pays the square (docs/classes.md).
--
-- `unstocked`: a trophy, seen on the rack and never sold (docs/drops.md).
local Curve = require("models.curve")

return {
    name = "Halo of the Morning",
    description = "Foes that start their turn able to see you have reduced accuracy until it ends.",
    flavor = "Nobody has ever looked straight at it twice. Nobody has ever managed to look away the first time.",
    sprite = "assets/items/armor_halo_of_the_morning.png",
    type = "armor",
    tags = { "medium", "holy" },
    class = "crusader",
    unlockLevel = 13,
    unstocked = true,
    bonus = { defense = Curve.ramp(3, 13), movement = -1 },
    traits = { "trait_light_bearer" },
}
