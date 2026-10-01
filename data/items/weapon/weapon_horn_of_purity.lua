-- HORN OF PURITY: what the Unicorn drops (data/characters/character_unicorn.lua; "Pride's Bestiary",
-- 2026-09-30). Its horn, cut down to a blade an exorcist can carry: a hit inflicts Blighted, and it strikes
-- for 3 more while its bearer carries no debuff -- the Unicorn's judgement, turned on the bearer as well as
-- the foe. A clean hand hits clean.
--
-- A DAGGER: quick (speed 2), and the wound does the rest (docs/weapons.md) -- the Blight standing in for the
-- family's Bleed, which is the one thing a horn would never do. An unstocked trophy on the approach's rung:
-- it is only ever found, on the Unicorn.
local Curve = require("models.curve")

local CLEAN_BONUS = 3 -- added to the blow's power while the bearer carries no debuff

local function clean(unit)
    for _, s in ipairs((unit and unit.statuses) or {}) do
        if s.def and s.def.debuff then return false end
    end
    return true
end

return {
    name = "Horn of Purity",
    description = "Inflicts Blighted. Increase damage by 3 while you carry no debuff.",
    flavor = "It went on judging after it was cut. It simply has less to say about you now.",
    sprite = "assets/items/weapon_horn_of_purity.png",
    type = "weapon",
    tags = { "dagger", "pierce", "physical", "holy", "melee" },
    class = "exorcist",
    unlockLevel = 13,
    unstocked = true,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 2, -- quick, like every dagger
        cost = { stat = "stamina", amount = 5 },
        damage = Curve.ramp(13, 23),
        effect = function(fx)
            local amount = (fx.amount or 0) + (clean(fx.user) and CLEAN_BONUS or 0)
            fx.damage(fx.target, { amount = amount, inflicts = "status_blighted" })
        end,
    },
}
