-- COVET: the Mimic-of-Ash throws back the last thing thrown at it.
--
-- The desert is the one board where both lines watch each other the whole way in -- open ground, slow
-- crossing, no cover (data/biomes/desert.lua). So on this floor your opening move is INFORMATION, and
-- this is the body that hands the information back.
--
-- Implemented as a strike scaled by what the mimic has been hit with rather than by re-casting a stored
-- ability: re-casting would mean a mimic that had eaten a party's best spell could delete the party with
-- it, and a body that copies your peak output is not counterplay, it is a coin flip. Instead it hits
-- harder the more it has been hit, which reads as the same idea at the board level -- swing big at it,
-- and it swings big back -- and stays inside the numbers its rung was authored for.
--
-- `struck` rides on the item instance, so two mimics on the same board each answer for their own
-- bruises rather than sharing one tally.
local Curve = require("models.curve")

local PER_WOUND = 2  -- damage added per blow it has taken
local CEILING = 14   -- ...and the cap, so a long fight cannot turn it into a general

return {
    name = "Ashen Echo",
    description = "Strikes an adjacent foe, harder for every blow it has taken.",
    flavor = "It has no opinions of its own. It has an excellent memory for other people's.",
    sprite = "assets/items/ashen_echo.png",
    type = "weapon",
    tags = { "natural", "impact", "physical", "melee" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 3,
        cost = { stat = "stamina", amount = 5 },
        damage = Curve.ramp(5, 15),
        effect = function(fx)
            local u = fx.user
            local hp = u.char and u.char.stats and u.char.stats.health
            local taken = 0
            if hp and hp.max then taken = math.max(0, hp.max - (hp.current or hp.max)) end
            -- Read off missing health rather than a counter, so it cannot drift out of step with the
            -- board and needs nothing stored between turns.
            local bonus = math.min(CEILING, math.floor(taken / 10) * PER_WOUND)
            fx.damage(fx.target, { amount = (fx.amount or 0) + bonus })
        end,
    },
}
