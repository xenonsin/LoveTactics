-- BOTTLED RAGE: the Goblin Brute's drop. Approved as pitched (2026-09-26, "The Goblins of Wrath"): the Brute's
-- burst, put under the bearer's control so it does not have to die for it.
--
-- Every hit you take adds a stack (status_bottled_rage, up to 5, trait_bottled_rage). As an action, spend them
-- all: every foe around you takes damage, more for each stack, and the free tiles around you catch fire. The
-- pitch called it a utility; it is an ABILITY because spending it is an action, and a utility has no action to
-- spend -- the stack-keeping rides on the ability's own trait, so the item is one thing in one cell.
local Curve = require("models.curve")

local PER_STACK = 5

return {
    name = "Bottled Rage",
    description = "Consume every Bottled Rage stack: damage each adjacent foe, plus 5 per stack, and set the tiles around you alight.",
    flavor = "It keeps a tally of every blow in the one place it never has to share.",
    sprite = "assets/items/ability_bottled_rage.png",
    type = "ability",
    tags = { "fire", "physical" },
    class = "barbarian",
    unlockLevel = 8,
    unstocked = true,
    traits = { "trait_bottled_rage" },
    activeAbility = {
        target = "self",
        range = 0,
        support = false,
        speed = 4,
        cost = { stat = "stamina", amount = 6 },
        damage = Curve.ramp(11, 21),
        aoe = { radius = 1, shape = "square" },
        usable = function(unit)
            if require("models.status").stacksOf(unit, "status_bottled_rage") < 1 then
                return false, "Nothing bottled up yet"
            end
            return true
        end,
        effect = function(fx)
            local user = fx.user
            local stacks = require("models.status").stacksOf(user, "status_bottled_rage")
            if stacks < 1 then return end
            local amount = (fx.amount or 0) + PER_STACK * stacks
            for _, u in ipairs(fx.aoeUnits()) do
                if u.side ~= user.side and u.alive then fx.damage(u, { amount = amount }) end
            end
            for dy = -1, 1 do
                for dx = -1, 1 do
                    local x, y = user.x + dx, user.y + dy
                    if not (dx == 0 and dy == 0) and not fx.unitAt(x, y) then
                        fx.placeHazard(x, y, "hazard_fire", { duration = 8 })
                    end
                end
            end
            fx.clearStatus(user, "status_bottled_rage")
        end,
    },
}
