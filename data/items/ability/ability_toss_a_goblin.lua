-- TOSS A GOBLIN: the Goblin King's reach (approved in round 2, 2026-09-26). He never leaves the throne, so his
-- court is his ammunition: he picks up a goblin beside him and throws it up to 5 tiles onto a foe. Both take the
-- landing, and the goblin then acts at once (fx.hasten). A body's own, never shelved.
local Curve = require("models.curve")

local function goblinBeside(fx)
    local Trait = require("models.trait")
    for _, u in ipairs(fx.unitsNear(fx.user.x, fx.user.y, 1)) do
        if u ~= fx.user and u.alive and u.side == fx.user.side and Trait.flag(u, "bloodFeud") then return u end
    end
    return nil
end

return {
    name = "Toss a Goblin",
    description = "Throws a goblin beside him onto a foe within 5. Both take the landing, and the goblin acts at once.",
    flavor = "The court has learned to stand a little further from the throne. It has not helped.",
    sprite = "assets/items/ability_toss_a_goblin.png",
    type = "ability",
    tags = { "impact", "physical" },
    class = "creature",
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 5,
        minRange = 2,
        speed = 4,
        cooldown = 10,
        cost = { stat = "stamina", amount = 6 },
        damage = Curve.ramp(10, 22),
        usable = function(unit)
            local combat = unit and unit.combat
            if combat then
                local Trait = require("models.trait")
                for _, u in ipairs(require("models.combat").unitsNear(combat, unit.x, unit.y, 1)) do
                    if u ~= unit and u.alive and u.side == unit.side and Trait.flag(u, "bloodFeud") then
                        return true
                    end
                end
            end
            return false, "No goblin beside him to throw"
        end,
        ai = { priority = "high", act = "cast" },
        effect = function(fx)
            local target = fx.target
            if not (target and target.alive) then return end
            local goblin = goblinBeside(fx)
            if not goblin then return end
            local x, y = fx.openTileNear(target.x, target.y)
            if not x then return end
            fx.teleport(goblin, x, y, { glide = true })
            fx.damage(target)
            fx.damage(goblin, { amount = math.floor((fx.amount or 0) / 2) })
            fx.hasten(goblin, 1.0)
        end,
    },
}
