-- LABRYS: the Minotaur's axe (data/characters/character_minotaur.lua; "The Minotaur", 2026-09-26/27), and one of
-- the two things it drops. The double-headed axe of the old bull cult: its swing cleaves the usual 3-wide arc in
-- front AND the same arc behind the wielder (`aoe.back`, Combat.aoeCells), so the body that got round behind it
-- is standing in the swing too.
--
-- Softer per target than a plain axe of its rung, because it may hit six. For a fighter who means to end up
-- surrounded. An unstocked trophy on floor eight's rung: it is only ever found, on the beast.
local Curve = require("models.curve")
return {
    name = "Labrys",
    description = "Deals damage in area, in front of you and behind you.",
    flavor = "Two heads, one haft. The bull cult never saw why an axe should only have one side.",
    sprite = "assets/items/weapon_labrys.png",
    type = "weapon",
    tags = { "axe", "slash", "physical", "melee" },
    class = "barbarian",
    unlockLevel = 8,
    unstocked = true,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 1,
        minRange = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 12 },
        damage = Curve.ramp(9, 19), -- per target: softer than an axe of its rung, and it may hit six
        aoe = { shape = "front", width = 3, back = true },
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do fx.damage(u) end
        end,
    },
}
