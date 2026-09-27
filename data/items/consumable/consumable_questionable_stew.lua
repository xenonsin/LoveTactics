-- QUESTIONABLE STEW: the Oni Greatblade's second drop. Approved 2026-09-26 ("The Oni of Wrath", round 1), after
-- Reincarnated as a Slime's retainer whose cooking rewrites what happens to whoever eats it, not always kindly.
--
-- An ally eats it and the dice decide: half the time a large heal and Empowered, half the time Poisoned. The roll is
-- the battle's own generator (fx.random), so a replay eats the same stew.
return {
    name = "Questionable Stew",
    description = "An ally eats it. Half the time: heal 40% of health and Empowered. The other half: Poisoned.",
    flavor = "She made it herself. She is standing right there, watching you eat it.",
    sprite = "assets/items/consumable_questionable_stew.png",
    type = "consumable",
    tags = { "food" },
    class = "barbarian",
    unlockLevel = 7,
    unstocked = true,
    activeAbility = {
        target = "ally",
        range = 1,
        speed = 2,
        consumesItem = true,
        effect = function(fx)
            local t = fx.target
            if not (t and t.alive) then return end
            if fx.random(2) == 1 then
                local Combat = require("models.combat")
                fx.heal(t, math.floor(Combat.unreservedMax(t.char, "health") * 0.4 + 0.5))
                fx.applyStatus(t, "status_empowered")
            else
                fx.applyStatus(t, "status_poison")
            end
        end,
    },
}
