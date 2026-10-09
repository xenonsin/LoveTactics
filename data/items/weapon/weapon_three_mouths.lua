-- THREE MOUTHS: Cerberus's bite ("The Crown's Bestiary", slice C, approved 2026-10-09). "It bites up to three
-- different adjacent bodies each turn, one bite per head."
--
-- One swing, as many bites as it has heads awake (GatePit.awake: alive and not asleep): the aimed body first, then
-- the next foes beside the body, never the same one twice. A head that has gone quiet bites nothing, so breaking or
-- sleeping heads takes bites off the dog; with none awake the mouths are shut (`usable`). The counter is the
-- review's: let only one body stand beside it, and three heads have one bite between them.
--
-- A demon's bite burns, as a physical blow (tests/bestiary_spec.lua's demon rule). Creature kit, never loot.
local Curve = require("models.curve")

local function awakeCount(combat, unit)
    if not combat then return 3 end -- a tooltip with no board quotes the dog whole
    return #require("models.gate_and_pit").awake(combat, unit)
end

return {
    name = "Three Mouths",
    description = "Bites one adjacent foe per waking head, never the same one twice.",
    flavor = "The middle head watches the door. The other two watch whoever is watching the middle head.",
    sprite = "assets/items/weapon_three_mouths.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "pierce", "physical", "fire", "melee" },
    noSteal = true, -- a creature's body is not loot
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 6 },
        damage = Curve.ramp(10, 22),
        usable = function(unit)
            if not (unit and unit.combat) then return true end
            if awakeCount(unit.combat, unit) > 0 then return true end
            return false, "every head is quiet"
        end,
        effect = function(fx)
            local n = awakeCount(fx.combat, fx.user)
            if n <= 0 then return end
            fx.damage(fx.target)
            local others = require("models.gate_and_pit").othersBeside(fx.combat, fx.user, fx.target, n - 1)
            for _, u in ipairs(others) do fx.damage(u) end
        end,
    },
}
