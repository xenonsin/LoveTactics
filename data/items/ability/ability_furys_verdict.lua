-- FURY'S VERDICT: the Erinys's trophy (data/characters/character_erinys.lua; "The Crown's Bestiary", slice B,
-- approved 2026-10-09). Her arrow handed over, three crimes of the four: a foe shot is Disarmed if it attacked on
-- its last turn, Silenced if it cast, Rooted if it moved (models/crown_demons.lua's verdict). A heal goes
-- unanswered here; Interred stays the Fury's own. An Inquisitor's, because a sentence that fits the deed is that
-- house's whole trade.
local Curve = require("models.curve")

-- The one crime the trophy does not answer.
local SPARED = { healed = true }

return {
    name = "Fury's Verdict",
    description = "Shoot a foe: Disarm it if it attacked last turn, Silence it if it cast, Root it if it moved.",
    flavor = "It is not a punishment if it fits. It is only a consequence that arrived on time.",
    sprite = "assets/items/ability_furys_verdict.png",
    type = "ability",
    tags = { "pierce", "physical", "ranged" },
    class = "inquisitor",
    unlockLevel = 15,
    unstocked = true,
    activeAbility = {
        target = "enemy",
        range = 5,
        minRange = 2,
        speed = 4,
        cooldown = 10,
        cost = { stat = "mana", amount = 10 },
        damage = Curve.ramp(16, 28),
        effect = function(fx) require("models.crown_demons").fitTheCrime(fx, SPARED) end,
    },
}
