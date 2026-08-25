-- Aldo's bound relic (Champion). He makes the fight come to him, then makes it regret arriving.
--
-- THE SHELF BRINGS THE BLOWS AND THIS SPENDS THEM. Provoke and Defiant Stand taunt; Reprisal and
-- Whirlplate answer; Crowd's Favour banks off allies being struck. All of them are ways of being hit
-- on purpose, which is exactly what the gate counts -- four blows weathered, the same tally the Sworn
-- Aegis uses, because a champion and a knight agree about what the work is and disagree about what it
-- is for. Rowan weathers to shove the ring off her charge; Aldo weathers to be swung at again.
--
-- WHAT IT DOES is bind the whole field to him for a turn and stand ready to answer. Not a strike --
-- the Champion's shelf is full of answers, and a relic that swung first would be playing somebody
-- else's game.
local Curve = require("models.curve")

return {
    name = "The Crowd's Due",
    description = "Taunts every foe on the field, and braces you to answer what comes.",
    flavor = "They paid to watch a fight. He has never once been the one who has to start it.",
    sprite = "assets/items/sig_crowds_due.png",
    type = "armor",
    tags = { "signature", "shield" },
    class = "knight",
    discipline = "champion",
    bonus = { defense = Curve.ramp(3, 13), movement = -1 },
    waitBehavior = { kind = "defend", speed = 3, defense = Curve.ramp(6, 16) },
    activeAbility = {
        target = "self",
        range = 0,
        speed = 5,
        cost = { stat = "stamina", amount = 12 },
        description = "Every foe must come at you, and you are braced when they do.",
        unlock = { event = "hitTaken", count = 4, text = "Weather 4 blows" },
        effect = function(fx)
            for _, u in ipairs((fx.combat and fx.combat.units) or {}) do
                if u.alive and u.side ~= fx.user.side then fx.applyStatus(u, "status_taunt") end
            end
            fx.applyStatus(fx.user, "status_defending")
        end,
    },
}
