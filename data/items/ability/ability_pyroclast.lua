-- PYROCLAST: the Thunderhead's own bolt, fire and lightning at once ("Fire, Lightning, and Dirty Thunder", round 2,
-- 2026-09-28), and one of the three things it drops. It lands as whichever of the two the target RESISTS LESS --
-- read through Combat.mitigatedDamage, the same arithmetic the blow will be charged by -- and sets the struck tile
-- alight. A caster's answer to a body that shrugs off one element; no other cast in the game picks.
--
-- (Named for what a volcano throws, not for the fight: the elite is Dirty Thunder, and a cast sharing its name would
-- read as the fight's own rule.)
local Curve = require("models.curve")

local ELEMENTS = { "fire", "lightning" }

-- The element `target` takes more of, fire on a tie.
local function weaker(target)
    local Combat = require("models.combat")
    local best, bestDmg
    for _, e in ipairs(ELEMENTS) do
        local d = Combat.mitigatedDamage(target, 100, { "magical", e })
        if not bestDmg or d > bestDmg then best, bestDmg = e, d end
    end
    return best
end

return {
    name = "Pyroclast",
    description = "A bolt of fire or lightning -- whichever the target resists less -- that sets the tile alight.",
    flavor = "The mountain does not care what you are proof against. It throws both.",
    sprite = "assets/items/ability_pyroclast.png",
    type = "ability",
    tags = { "magical" },
    class = "mage",
    unlockLevel = 8,
    unstocked = true,
    activeAbility = {
        target = "enemy",
        range = 3,
        requiresSight = true,
        speed = 3,
        cost = { stat = "mana", amount = 10 },
        damage = Curve.ramp(10, 20),
        effect = function(fx)
            local t = fx.target
            if not t then return end
            fx.damage(t, { tags = { weaker(t) } })
            fx.placeHazard(t.x, t.y, "hazard_fire", { amount = 3 + fx.level, duration = 8 + fx.level })
        end,
    },
}
