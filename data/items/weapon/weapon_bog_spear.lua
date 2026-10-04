-- BOG SPEAR: the Bog Body's own (data/characters/character_bog_body.lua; "Sloth's Bestiary", 2026-10-04, slice C).
-- A peat-black spear that went into the mire with its soldier and came up with it: reach 2, the spear's line.
-- The creature's copy of the Peat-Black Spear, which is the Sentinel's and is what the body drops -- a creature
-- may not carry an earned class's stock (tests/bestiary_spec.lua).
local Curve = require("models.curve")

return {
    name = "Bog Spear",
    description = "Skewers the two tiles directly in front of you.",
    flavor = "The shaft went black in the peat. So did the hand.",
    sprite = "assets/items/weapon_bog_spear.png",
    type = "weapon",
    class = "creature",
    tags = { "spear", "pierce", "physical", "melee" }, -- a spear, not `natural`: a weapon is one family
    noSteal = true, -- a creature's body is not loot
    activeAbility = {
        target = "tile",       -- a spear: aim an adjacent tile, and the thrust runs two deep
        allowOccupied = true,
        range = 1,
        minRange = 1,
        speed = 3,
        cost = { stat = "stamina", amount = 6 },
        damage = Curve.ramp(8, 18),
        aoe = { shape = "line", length = 2 },
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do fx.damage(u) end
        end,
    },
}
