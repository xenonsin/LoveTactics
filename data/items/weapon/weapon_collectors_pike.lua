-- THE COLLECTOR'S PIKE: what the Toll-Collector drops (data/characters/character_toll_collector.lua; "Sloth's
-- Bestiary", 2026-10-04, slice F, approved word for word). Pierces two tiles in a line, as every spear does, and deals
-- 50% more to a foe with an ally beside it.
--
-- The collector's own lesson turned round. Its pike punishes a company that stands in file; this one punishes a
-- line that stands shoulder to shoulder -- so the Bastion's spear finally has a reason to aim at the middle of a
-- formation rather than its end. "Beside" is edge-on, read on each body the thrust reaches as it stands.
--
-- A KNIGHT'S, where the spears are. An unstocked trophy on the seat's rung.
local Curve = require("models.curve")

return {
    name = "Collector's Pike",
    description = "Pierces two tiles in a line. Deals 50% more to a foe with an ally beside it.",
    flavor = "It charges by the head, and it has never once been short-changed by a crowd.",
    sprite = "assets/items/weapon_collectors_pike.png",
    type = "weapon",
    tags = { "spear", "pierce", "physical", "melee" },
    hands = 2,
    class = "knight",
    unlockLevel = 10,
    unstocked = true,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 1,
        minRange = 1,
        speed = 3,
        cost = { stat = "stamina", amount = 8 },
        damage = Curve.ramp(13, 23), -- the slot-10 spear target (tests/balance_spec.lua)
        aoe = { shape = "line", length = 2 },
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                local flanked = false
                for _, n in ipairs(fx.unitsNear(u.x, u.y, 1) or {}) do
                    if n ~= u and n.alive and n.side == u.side then flanked = true end
                end
                local bonus = flanked and math.floor(fx.amount * 0.5) or 0
                fx.damage(u, { amount = fx.amount + bonus })
            end
        end,
    },
}
