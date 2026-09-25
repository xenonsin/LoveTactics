-- THE GULLET: the Giant Toad's swallow, for a person. Take a foe beside you down whole (status_swallowed):
-- it is out of the fight and digesting -- healing you -- until you take a heavy blow, are stunned, fall, or
-- two turns run out, and then it comes back out Wet. While it is inside you are Full.
--
-- WHY IT IS SMALLER THAN THE TOAD'S, on every axis the review could see (2026-09-25). A swallow does two
-- jobs at once -- it removes an enemy and it feeds you -- and on the company's side the removal is already
-- the prize. So the meal is the SATED'S size (+3/+3), not the toad's double, the stay is two turns rather
-- than three, and a long cooldown makes it roughly one swallow a fight. It never takes a boss
-- (Combat.canSwallow), and the heavy-blow rule (trait_gullet) is the same one the toad answers to, so an
-- enemy that hits you hard enough gets its friend back.
--
-- Barbarian stock beside the Bottomless Gut -- the shelf that eats -- and rift-only: a trophy off the toad.
local Combat = setmetatable({}, { __index = function(_, k) return require("models.combat")[k] end })

local MEAL = { damage = 3, defense = 3, movement = -1 }

return {
    name = "The Gullet",
    description = "Swallows an adjacent non-boss foe to digest for 2 turns; while it is inside, gain +3 "
        .. "damage and +3 defense.",
    flavor = "You will not enjoy it. Neither will they, and they are the one inside.",
    sprite = "assets/items/ability_the_gullet.png",
    type = "ability",
    tags = { "physical" },
    class = "barbarian",
    unlockLevel = 4,
    unstocked = true,
    traits = { "trait_gullet" },
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 5,
        cooldown = 40, -- about eight turns: one swallow a fight, near enough
        cost = { stat = "stamina", amount = 10 },
        usable = function(unit)
            if unit.swallowing then return false, "Your mouth is full" end
            return true
        end,
        effect = function(fx)
            local t = fx.target
            if not t then return end
            if fx.combat and not Combat.canSwallow(fx.combat, fx.user, t) then return end
            local st = fx.applyStatus(t, "status_swallowed", { magnitude = 4, duration = 10, applier = fx.user })
            if st then fx.applyStatus(fx.user, "status_full", { magnitude = 1, statBonus = MEAL }) end
        end,
    },
}
