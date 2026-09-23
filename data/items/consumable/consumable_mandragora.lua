-- Mandragora: the old surgeons' sleeping draught, made from the root the Alraune grows out of. It heals
-- the drinker completely and puts them under (status_sleep), and any blow wakes them.
--
-- A FULL HEAL THAT COSTS A TURN ORDER, which is the decision the Alraune spends her whole fight forcing
-- on a company and this hands back to it on its own terms. Drunk behind the line, it is the best potion
-- in the game; drunk where anything can reach, it is a heal and a free first blow for whoever reaches.
-- Sleep breaks on damage and hands back the time it had not yet taken (data/status/status_sleep.lua),
-- so a sleeper struck at once loses almost nothing -- the cost is only real if nobody touches them.
--
-- `unstocked`: found only, off the Alraune line (tests/discovery_spec.lua names it).
return {
    name = "Mandragora",
    description = "Restores all health, and puts the drinker to sleep.",
    flavor = "Not poppy, nor mandragora, nor all the drowsy syrups of the world. Well: one of those.",
    sprite = "assets/items/consumable_mandragora.png",
    type = "consumable",
    tags = { "potion", "restorative" },
    class = "apothecary",
    unstocked = true,
    unlockLevel = 15,
    activeAbility = {
        target = "ally", -- includes the user (a unit is its own ally)
        range = 1,
        speed = 2,
        support = true,
        consumesItem = true,
        effect = function(fx)
            -- Everything: Combat.applyHeal caps a heal at the body's unreserved ceiling, so an amount no
            -- bar in the game reaches is "all of it" without this file learning how a ceiling is read.
            fx.heal(fx.target, 9999)
            fx.applyStatus(fx.target, "status_sleep")
        end,
    },
}
