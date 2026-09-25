-- VEINFINDER: the Earth Golem's drop (round 1, "The Golems of Greed", with the note "any obstacle"). Strike
-- the Vein as a verb: mine an obstacle beside you -- a wall, rubble, a standing object, solid rock -- and
-- it comes away leaving a coin heap where it stood. Twice a fight.
--
-- It opens a lane and pays gold, and in a dwarf fight the heap it leaves is bait the whole line runs for.
-- The mining goes through fx.mine (models/golem.lua), because a preview replays this effect against the
-- real board. The count rides status_veins_struck, which a preview records and never lays.
local Status = require("models.status")

return {
    name = "Veinfinder",
    description = "Mines an adjacent obstacle (a wall, rubble, an object or rock) and leaves a coin heap where it stood. Twice a fight.",
    flavor = "The trick is not finding gold in a mountain. The trick is finding the part that is not.",
    sprite = "assets/items/ability_veinfinder.png",
    type = "ability",
    tags = { "earth", "guile" },
    class = "mammonite",
    price = 380,
    unlockLevel = 5,
    activeAbility = {
        target = "tile",
        aimsObstacle = true, -- aimed AT the wall, not at an empty tile (Combat.useItem)
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 5 },
        usable = function(unit)
            if Status.stacksOf(unit, "status_veins_struck") >= 2 then return false, "Twice a fight" end
            return true
        end,
        effect = function(fx)
            if fx.mine(fx.tx, fx.ty) then
                fx.applyStatus(fx.user, "status_veins_struck", { magnitude = 1 })
            end
        end,
    },
}
