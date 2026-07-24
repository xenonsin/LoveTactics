-- Detonator: the rogue half of the Saboteur (rogue x alchemist). Every charge you have planted goes off
-- at once.
--
-- The item S3 was built for, and the one the shelf shipped without: Ghost Kit's header has admitted
-- since it was written that it detonates a CHOSEN TILE rather than triggering charges laid earlier,
-- because the engine had no way to remember a thing planted now and resolved later. It does now
-- (Combat.plantCharge / detonateAll), and the approximation can be retired.
--
-- It is the whole reason a saboteur plays differently from a bombardier. A bomb is a decision you make
-- and resolve in one turn; a charge is a decision you make about a turn that has not happened. The
-- Sapper's Line puts three of them in the ground on a two-turn fuse, and this is the option to stop
-- waiting -- which is what makes the fuse a threat rather than a countdown the enemy can simply read.
--
-- Charges belong to nobody once they are in the ground. This catches your own line if your own line is
-- standing on them, exactly as a powder keg does.
return {
    name = "Detonator",
    description = "Sets off every charge you have planted, wherever they are.",
    flavor = "The waiting was the plan. The plunger is barely part of it.",
    sprite = "assets/items/ability_detonator.png",
    type = "ability",
    tags = { "utility" },
    class = "rogue",
    discipline = "saboteur",
    price = 340,
    repRank = 4,
    activeAbility = {
        target = "self",
        range = 0,
        speed = 2, -- barely a beat: the work was done turns ago
        cost = { stat = "stamina", amount = 4 },
        description = "Detonates all of your planted charges at once.",
        effect = function(fx)
            local Combat = require("models.combat")
            local n = Combat.detonateAll(fx.combat, fx.user)
            if n == 0 then fx.log("action", "Nothing is wired. The plunger goes down on an empty line.") end
        end,
    },
}
