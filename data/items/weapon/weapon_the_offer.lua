-- THE OFFER: the Pit Imp's sting (data/characters/character_pit_imp.lua; "The Crown's Bestiary", slice B, approved
-- 2026-10-09). The sting lays Blood Debt on what it strikes: +5 damage for 2 turns, and a third of everything dealt
-- under it charged back when it runs out (data/status/status_blood_debt.lua). It is a real choice for the stung
-- body, not a pure debuff -- spend the borrowed power fast with a healer ready, or Cure it before it comes due.
--
-- A demon's blow burns: a physical sting with fire on it (tests/bestiary_spec.lua's demon rule).
local Curve = require("models.curve")

return {
    name = "The Offer",
    description = "Stings an adjacent foe and puts Blood Debt on it.",
    flavor = "It holds out the pen before it holds out the terms.",
    sprite = "assets/items/weapon_the_offer.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "pierce", "physical", "fire", "melee" },
    noSteal = true, -- a creature's body is not loot
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 5 },
        damage = Curve.ramp(5, 15),
        effect = function(fx)
            local t = fx.target
            if not t then return end
            fx.damage(t)
            if t.alive then fx.applyStatus(t, "status_blood_debt") end
        end,
    },
}
