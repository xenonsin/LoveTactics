-- UNDERTOW: Leviathan's rising, lifted off it for an elementalist (data/characters/character_leviathan.lua;
-- "Envy's Bestiary", row lv_drops, approved word for word). Mark a 3x3; at the start of your next turn it
-- erupts -- damage to every foe in it, everyone in it shoved out, and the nine tiles quicksand for the rest of
-- the fight.
--
-- A WIND-UP, which is what "at the start of your next turn" is in this engine: the channel's ghost is the mark,
-- a turn early, and the eruption is its resolution. The eruption itself is models/leviathan.lua's own
-- Leviathan.erupt, run through this cast's helpers, so the drop and the boss cannot disagree about what a
-- rising does -- and a hovered aim records the shove rather than making it.
--
-- An unstocked trophy on the approach's rung (floor 11, the stair it stands on), noSteal like every stair piece.
local Curve = require("models.curve")

return {
    name = "Undertow",
    description = "Mark a 3×3. At the start of your next turn it erupts: damage, everyone in it shoved out, and it becomes quicksand.",
    flavor = "The waste remembers being a sea. It only needs a reminder.",
    sprite = "assets/items/ability_undertow.png",
    type = "ability",
    tags = { "earth", "magical" },
    class = "elementalist",
    unlockLevel = 11,
    unstocked = true,
    noSteal = true,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 4,
        speed = 5,
        windup = 5, -- a turn: it erupts as your next turn comes round
        cost = { stat = "mana", amount = 14 },
        damage = Curve.ramp(13, 23),
        aoe = { radius = 1, shape = "square" },
        effect = function(fx)
            -- The item tooltip's static run has no board: strike what it is shown and lay the sand.
            if not fx.combat then
                for _, u in ipairs(fx.aoeUnits()) do fx.damage(u) end
                fx.placeHazard(fx.tx, fx.ty, "hazard_quicksand", { duration = 9999 })
                return
            end
            local Leviathan = require("models.leviathan")
            Leviathan.erupt(fx.combat, fx.user, fx.tx, fx.ty, Leviathan.castOps(fx))
        end,
    },
}
