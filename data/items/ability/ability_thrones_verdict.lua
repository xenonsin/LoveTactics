-- THRONE'S VERDICT: the Throne's drop, its Decree rebuilt for a person (reviewed 2026-09-30, "Pride's Bestiary").
-- Light a 3x3 area; at the start of the caster's next turn it deals holy damage to every foe still standing in it.
--
-- A one-turn wind-up (5 ticks), so the lit square is painted by the same telegraph the Throne's pattern was -- and
-- a foe reading it walks out, exactly as the company did. Holy Light is the priest's version of a pillar of light
-- and lands a little sooner and lighter; this is the Inquisitor's, a heavier verdict from further off, priced on a
-- cooldown because a sentence is not something you pass every turn.
--
-- `unstocked`: a trophy, seen on the inquisitor's rack and never sold (docs/drops.md).
local Curve = require("models.curve")

return {
    name = "Throne's Verdict",
    description = "Light a 3x3 area. At the start of your next turn it deals holy damage.",
    flavor = "The light arrives first. What it was sent to announce arrives exactly one breath later.",
    sprite = "assets/items/ability_thrones_verdict.png",
    type = "ability",
    tags = { "holy", "magical" },
    class = "inquisitor",
    unlockLevel = 10,
    unstocked = true,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 5,
        speed = 4,
        windup = 5, -- one turn: the verdict lands when the caster's slot comes back round
        cooldown = 15,
        cost = { stat = "mana", amount = 14 },
        damage = Curve.ramp(13, 25),
        aoe = { radius = 1, shape = "square" }, -- the 3x3
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                if u ~= fx.user and u.alive and u.side ~= fx.user.side then fx.damage(u) end
            end
        end,
    },
}
