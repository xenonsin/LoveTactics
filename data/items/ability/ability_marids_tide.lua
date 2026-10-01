-- MARID'S TIDE: the Marid's flood, and its drop. Reviewed 2026-09-30 ("Pride's Bestiary").
--
-- A 3x3 burst of water: every body inside is Wet (status_wet, Rain's own soaking -- lightning and ice bite
-- harder, fire less), and the caster heals for every Wet foe on the board once the water has landed. Not only the
-- ones it just caught: a company that walked out of a Rain is a company the Marid drinks from as well, so the
-- answer is to stay dry, or to make the Marid's flood the last thing it casts.
--
-- Unsided like all weather, so it soaks the Marid's own line too -- and puts out the Ifrit's fires under them.
local Curve = require("models.curve")

-- Health per Wet foe.
local PER_FOE = 8

return {
    name = "Marid's Tide",
    description = "Flood a 3x3 area: every body inside is Wet, and you heal for each Wet foe.",
    flavor = "The sea does not come to you. It simply finds out where you are standing.",
    sprite = "assets/items/ability_marids_tide.png",
    type = "ability",
    tags = { "water", "magical" },
    class = "druid",
    unlockLevel = 13,
    unstocked = true,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 3,
        requiresSight = true,
        speed = 4,
        cost = { stat = "mana", amount = 12 },
        damage = Curve.ramp(15, 25), -- a soaking, not a drowning: the Wet is the spell
        aoe = { radius = 1, shape = "square" },
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                fx.damage(u)
                if u.alive then fx.applyStatus(u, "status_wet") end
            end
            local wet = 0
            for _, u in ipairs(fx.unitsNear(fx.user.x, fx.user.y, 99)) do
                if u.alive and u.side ~= fx.user.side and fx.hasStatus(u, "status_wet") then wet = wet + 1 end
            end
            if wet > 0 then fx.heal(fx.user, PER_FOE * wet) end
        end,
    },
}
