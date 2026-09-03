-- Crucible rank-2. A flask of caustic brew that bursts in a small blast and eats the ARMOR off
-- everything caught in it: each victim is left Corroded (data/status/acid.lua), its defense and magic
-- defense cut for a time. It does modest damage of its own -- the point is what comes next. Soften a
-- heavily-plated line with a bomb, then let the party's real hitters land on bare skin.
--
-- The alchemist's take on "removing armor": not stealing the plate (that is Greed) but making it stop
-- working (Envy). Carries no "magical" tag; the corrosion cares nothing for magic defense to apply.
local Curve = require("models.curve")

return {
    name = "Acid Bomb",
    description = "Inflicts Acid in area.",
    flavor = "The Crucible's answer to armor: not taking the plate off a body. That is Greed, but making it stop working.",
    sprite = "assets/items/acid_bomb.png",
    type = "consumable",
    tags = { "acid" },
    class = "bombardier", -- deeper cut of the shelf: buyable only once the bombardier gate is cleared
    price = 295,
    unlockQuests = 8,
    activeAbility = {
        target = "tile", -- thrown at a foe and bursts around it, like Fireball
        allowOccupied = true,
        range = 3,
        requiresSight = true,
        speed = 4,
        cost = { stat = "stamina", amount = 5 },
        damage = Curve.ramp(6, 16), -- flat, modest: the debuff is the payload, not the splash
        consumesItem = true,
        aoe = { radius = 1, shape = "square" },
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                fx.damage(u)
                fx.applyStatus(u, "status_acid")
            end
        end,
    },
}
